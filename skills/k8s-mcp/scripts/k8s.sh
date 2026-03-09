#!/bin/sh
set -eu

# k8s-mcp: Read-only Kubernetes diagnostics without kubectl
# Uses the in-cluster ServiceAccount token + CA to call the Kubernetes API.

API_HOST="${KUBERNETES_SERVICE_HOST:-kubernetes.default.svc}"
API_PORT="${KUBERNETES_SERVICE_PORT:-443}"
API_SERVER="https://${API_HOST}:${API_PORT}"

TOKEN_PATH="/var/run/secrets/kubernetes.io/serviceaccount/token"
CA_PATH="/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
NS_PATH="/var/run/secrets/kubernetes.io/serviceaccount/namespace"

DEFAULT_NS="openclaw"
DEFAULT_LIMIT="200"

die() { echo "ERROR: $*" >&2; exit 1; }

need_file() {
  [ -f "$1" ] || die "Missing required file: $1"
}

kube_get() {
  # $1 = path (must start with /)
  path="$1"
  need_file "$TOKEN_PATH"
  need_file "$CA_PATH"

  token="$(cat "$TOKEN_PATH" | tr -d '\n')"
  [ -n "$token" ] || die "ServiceAccount token is empty"

  # Print raw JSON (or raw text for /version)
  curl -sS --fail \
    --cacert "$CA_PATH" \
    -H "Authorization: Bearer ${token}" \
    -H "Accept: application/json" \
    "${API_SERVER}${path}"
}

print_usage() {
  cat <<EOF
Usage:
  $0 events [namespace] [limit]
  $0 warnings [namespace] [limit]
  $0 helm-list [namespace]
  $0 config
  $0 version

Defaults:
  namespace = ${DEFAULT_NS}
  limit     = ${DEFAULT_LIMIT}
EOF
}

cmd="${1:-}"
shift || true

case "$cmd" in
  events|warnings)
    ns="${1:-$DEFAULT_NS}"
    limit="${2:-$DEFAULT_LIMIT}"

    # Basic validation
    case "$limit" in
      ''|*[!0-9]*)
        die "limit must be an integer (got: $limit)"
        ;;
    esac

    kube_get "/api/v1/namespaces/${ns}/events" | node -e "
const fs = require('fs');

function pad(n){ return String(n).padStart(2,'0'); }
function fmtTs(ts){
  if(!ts) return '';
  const d = new Date(ts);
  if(isNaN(d.getTime())) return ts;
  const yyyy = d.getFullYear();
  const mm = pad(d.getMonth()+1);
  const dd = pad(d.getDate());
  const HH = pad(d.getHours());
  const MM = pad(d.getMinutes());
  const SS = pad(d.getSeconds());
  const offMin = -d.getTimezoneOffset(); // minutes east of UTC
  const sign = offMin >= 0 ? '+' : '-';
  const oh = pad(Math.floor(Math.abs(offMin)/60));
  const om = pad(Math.abs(offMin)%60);

  let tzName = '';
  try {
    tzName = new Intl.DateTimeFormat('en-US', { timeZoneName: 'short' })
      .formatToParts(d)
      .find(p => p.type === 'timeZoneName')?.value || '';
  } catch(e) {}

  return \`\${yyyy}-\${mm}-\${dd} \${HH}:\${MM}:\${SS} \${sign}\${oh}\${om}\${tzName ? ' ' + tzName : ''}\`;
}

function evTs(e){
  return e.lastTimestamp || e.eventTime || e.firstTimestamp || (e.metadata && e.metadata.creationTimestamp) || '';
}

const input = fs.readFileSync(0, 'utf8').trim();
if(!input){
  console.log('# No data returned.');
  process.exit(0);
}

let obj;
try { obj = JSON.parse(input); }
catch(e){
  console.log(input);
  process.exit(0);
}

let items = Array.isArray(obj.items) ? obj.items : [];
items.sort((a,b) => (evTs(a) || '').localeCompare(evTs(b) || ''));

const limit = Number(process.argv[1] || '200');
if(Number.isFinite(limit) && limit > 0 && items.length > limit){
  items = items.slice(items.length - limit);
}

const warningsOnly = process.argv[2] === 'warnings';

if(warningsOnly){
  items = items.filter(e => (e.type || '') === 'Warning');
}

console.log('# The following events (YAML format) were found:');
if(items.length === 0){
  console.log('# (none)');
  process.exit(0);
}

for(const e of items){
  const io = e.involvedObject || e.regarding || {};
  const ts = fmtTs(evTs(e));
  const msg = (e.message || '').replace(/\\r/g,'');
  const ns = e.metadata?.namespace || e.namespace || '';
  const reason = e.reason || '';
  const type = e.type || '';

  console.log('- InvolvedObject:');
  if(io.kind) console.log('    Kind: ' + io.kind);
  if(io.name) console.log('    Name: ' + io.name);
  if(io.apiVersion) console.log('    apiVersion: ' + io.apiVersion);

  if(msg) console.log('  Message: ' + msg.split('\\n').join('\\n    '));
  if(ns) console.log('  Namespace: ' + ns);
  if(reason) console.log('  Reason: ' + reason);
  if(ts) console.log('  Timestamp: ' + ts);
  if(type) console.log('  Type: ' + type);
}
" "$limit" "$cmd"
    ;;
  helm-list)
    ns="${1:-$DEFAULT_NS}"

    # Helm v3 stores releases as Secrets labeled owner=helm (type: helm.sh/release.v1)
    # This requires RBAC to list secrets in the namespace.
    kube_get "/api/v1/namespaces/${ns}/secrets?labelSelector=owner%3Dhelm" | node -e "
const fs = require('fs');

const input = fs.readFileSync(0,'utf8').trim();
if(!input){ console.log('# No data returned.'); process.exit(0); }

let obj;
try { obj = JSON.parse(input); } catch(e){ console.log(input); process.exit(0); }

const items = Array.isArray(obj.items) ? obj.items : [];
if(items.length === 0){
  console.log('# No Helm secrets found (or none accessible).');
  process.exit(0);
}

const rows = [];
for(const s of items){
  const labels = s.metadata?.labels || {};
  const release = labels.name || '(unknown)';
  const revision = labels.version || '(unknown)';
  const status = labels.status || '(unknown)';
  const created = s.metadata?.creationTimestamp || '';
  const secretName = s.metadata?.name || '';
  rows.push({ release, revision, status, created, secretName });
}

// Keep only latest revision per release (numeric compare if possible)
const byRelease = new Map();
for(const r of rows){
  const prev = byRelease.get(r.release);
  const rv = parseInt(r.revision, 10);
  const pv = prev ? parseInt(prev.revision, 10) : NaN;

  if(!prev){
    byRelease.set(r.release, r);
  } else if(Number.isFinite(rv) && Number.isFinite(pv) && rv > pv){
    byRelease.set(r.release, r);
  } else if(!Number.isFinite(pv) && Number.isFinite(rv)){
    byRelease.set(r.release, r);
  }
}

const out = Array.from(byRelease.values()).sort((a,b)=>a.release.localeCompare(b.release));

console.log('RELEASE\\tREVISION\\tSTATUS\\tCREATED\\tSECRET');
for(const r of out){
  console.log([r.release, r.revision, r.status, r.created, r.secretName].join('\\t'));
}
"
    ;;
  config)
    ns="unknown"
    if [ -f "$NS_PATH" ]; then ns="$(cat "$NS_PATH" | tr -d '\n')"; fi

    echo "apiServer: ${API_SERVER}"
    echo "namespace: ${ns}"
    echo "serviceAccountToken: $( [ -f "$TOKEN_PATH" ] && echo present || echo missing )"
    echo "serviceAccountCA: $( [ -f "$CA_PATH" ] && echo present || echo missing )"
    ;;
  version)
    kube_get "/version"
    ;;
  ""|help|-h|--help)
    print_usage
    ;;
  *)
    die "Unknown command: $cmd (try: $0 --help)"
    ;;
esac
