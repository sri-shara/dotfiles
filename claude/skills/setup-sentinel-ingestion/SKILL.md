---
name: setup-sentinel-ingestion
description: >
  Wire Microsoft Sentinel ingestion for a local-dev tenant end to end: upsert
  the credential/flag tenant_settings (client secret as plaintext), resolve the
  live integration_id, start the SourceFetcherWorkflow via
  EnsureIngestionConfiguration, and verify incidents are fetched → formatted →
  written to the ingestion-batches bucket. Triggers on "set up sentinel
  ingestion", "wire sentinel", "configure sentinel ingestion locally",
  "start the sentinel fetcher".
allowed-tools: Bash, Read, Grep, Glob
argument-hint: "[tenant name/alias/uuid] (default: tnxdmo)"
---

# Set Up Microsoft Sentinel Ingestion (local dev)

Wires Sentinel ingestion for one local tenant and proves it's flowing. Every step
is **idempotent** — re-running is safe and also serves as a health check.

```
EnsureIngestionConfiguration (gRPC :8075, served by nucleusmanager)
  └─ upserts ingestion_configurations + starts Temporal SourceFetcherWorkflow
       └─ every fetch_interval_seconds, per page:
            FetchSentinelIncidentsActivity  ← reads creds from tenant_settings via SettingsService
            FormatSentinelBatchActivity     → RawAlert JSONL
            WriteBatchToGCSActivity         → upload to `ingestion-batches` + notify
            RecordFetchMetadataActivity     → advance mod-time cursor
       (downstream: Batch Splitter → OCSF Parser → alerts → cases)
```

> Credentials live in 1Password: `op read "op://TENEX Engineering/Sentinel Credentials/<KEY>"`
> with keys `MICROSOFT_SENTINEL_{TENANT_ID,CLIENT_ID,CLIENT_SECRET,WORKSPACE_RESOURCE_ID}`.

## Critical gotchas (why this skill exists)

1. **Store the client secret as PLAINTEXT in `tenant_settings`. Do NOT use
   SaveCredentials / the UI.** Locally (`platformEnv=local`) `SettingsService`
   returns the `setting_value` column verbatim and skips Secret Manager
   resolution. SaveCredentials writes a `memory/…` secret-store *reference* that
   the local read path hands back literally → the Sentinel client gets `memory/…`
   as the "secret" → Azure auth fails. Plaintext is the sanctioned local-only
   workaround. **Never** point these plaintext settings at a shared/prod SettingsService.
2. **`integration_id` is reseeded on every `task dev:reset`.** Never hardcode it —
   always re-query `integration_catalog`. (Resolving it live is also why this skill
   survives a reset.)
3. **`kubectl port-forward` is pinned to a pod.** When `nucleusmanager` redeploys,
   `:8075` dies and must be re-established.
4. **`op whoami` lies under the desktop-app integration** — it reports "account is
   not signed in" even when `op read` works fine. Probe with an actual `op read`.
5. **Two fetch lanes per config:** `…-hot` (your interval/lookback) and `…-cold`
   (service overrides to ~1 h interval / 24 h lookback for backfill). The hot lane
   is the reliable health signal.
6. **Known issue:** the cold lane can hit `HTTP 400` *with an HTML body* when
   following an ARM `nextLink` on a deeper page (a page-2 path the POC never
   exercised; see `integrations/microsoftsentinel/client.go` `FollowNextLink`).
   It does **not** block the hot lane. Flag it; don't treat it as a setup failure.

---

## Step 0 — Prerequisites

Resolve the tenant and confirm the moving parts are up. Default tenant is `tnxdmo`.

```sh
ARG="${1:-tnxdmo}"   # accepts a name/alias substring OR a full UUID

DB() { kubectl exec -i postgres-0 -- psql -U postgres -d nucleus_dev "$@"; }

# Resolve ARG → tenant_id (UUID passes through; otherwise match name/alias)
if printf '%s' "$ARG" | grep -Eiq '^[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}$'; then
  TENANT="$ARG"
else
  TENANT=$(DB -tA -c "SELECT tenant_id FROM tenants WHERE name ILIKE '%$ARG%' OR alias ILIKE '%$ARG%' ORDER BY created_at LIMIT 1;")
fi
[ -n "$TENANT" ] || { echo "ERROR: no tenant matched '$ARG'"; exit 1; }
echo "tenant_id = $TENANT"

# (a) Worker that runs the fetch activities + the gRPC host must be up
kubectl get pods | grep -E 'ingestiongoworker|nucleusmanager' || { echo "stack not up — run: task dev:up:all"; exit 1; }
kubectl wait --for=condition=Ready pod -l app=nucleusmanager --timeout=120s

# (b) :8075 reachable? If not, (re)establish the port-forward in the background.
if ! grpcurl -plaintext -max-time 4 localhost:8075 list 2>/dev/null | grep -q ingestioncontrolservice; then
  echo "starting port-forward nucleusmanager:8075 …"
  (kubectl port-forward svc/nucleusmanager 8075:8075 >/tmp/pf-8075.log 2>&1 &) ; sleep 3
  grpcurl -plaintext -max-time 5 localhost:8075 list | grep -q ingestioncontrolservice || { echo "ERROR: :8075 still unreachable"; cat /tmp/pf-8075.log; exit 1; }
fi
echo ":8075 OK"

# (c) 1Password reachable (op whoami is unreliable — probe with a real read of a non-secret field)
op read "op://TENEX Engineering/Sentinel Credentials/MICROSOFT_SENTINEL_CLIENT_ID" >/dev/null \
  || { echo "ERROR: op can't read the vault — enable 1Password desktop CLI integration / unlock the app"; exit 1; }
echo "op OK"
```

> When run from Claude Code, prefer launching the port-forward with
> `run_in_background: true` rather than `&`, and re-run it if a `nucleusmanager`
> redeploy kills it.

## Step 1 — Upsert tenant_settings (secret stays out of the transcript)

```sh
VAULT="TENEX Engineering"; ITEM="Sentinel Credentials"
TID=$(op read "op://$VAULT/$ITEM/MICROSOFT_SENTINEL_TENANT_ID")
CID=$(op read "op://$VAULT/$ITEM/MICROSOFT_SENTINEL_CLIENT_ID")
SECRET=$(op read "op://$VAULT/$ITEM/MICROSOFT_SENTINEL_CLIENT_SECRET")
WSID=$(op read "op://$VAULT/$ITEM/MICROSOFT_SENTINEL_WORKSPACE_RESOURCE_ID")
for v in "$TID" "$CID" "$SECRET" "$WSID"; do [ -n "$v" ] || { echo "ERROR: empty op read — aborting"; exit 1; }; done
esc() { printf "%s" "$1" | sed "s/'/''/g"; }   # double single-quotes for SQL literals

printf "%s" "INSERT INTO tenant_settings (tenant_id, setting_key, setting_value) VALUES
  ('$TENANT','FLAG_ENABLE_MICROSOFT_SENTINEL_INGESTION','true'),
  ('$TENANT','MICROSOFT_SENTINEL_TENANT_ID','$(esc "$TID")'),
  ('$TENANT','MICROSOFT_SENTINEL_CLIENT_ID','$(esc "$CID")'),
  ('$TENANT','MICROSOFT_SENTINEL_CLIENT_SECRET','$(esc "$SECRET")'),
  ('$TENANT','MICROSOFT_SENTINEL_WORKSPACE_RESOURCE_ID','$(esc "$WSID")')
ON CONFLICT (tenant_id, setting_key) DO UPDATE SET setting_value = EXCLUDED.setting_value, updated_at = now();" | DB

# Verify (masked — never print secret values)
DB -c "SELECT setting_key, left(setting_value,6)||'…('||length(setting_value)||' chars)' AS preview
       FROM tenant_settings WHERE tenant_id='$TENANT' AND setting_key LIKE '%SENTINEL%' ORDER BY setting_key;"
```

Expect 5 rows; `FLAG_… = true (4 chars)`, secret ~40 chars, workspace id ~160 chars.

## Step 2 — Resolve the live integration_id

```sh
IID=$(DB -tA -c "SELECT integration_id FROM integration_catalog WHERE identifier='microsoft-sentinel';")
[ -n "$IID" ] || { echo "ERROR: microsoft-sentinel not in integration_catalog (reseed/migrations?)"; exit 1; }
echo "integration_id = $IID"
```

## Step 3 — Start the fetcher (create-or-recover)

```sh
grpcurl -plaintext -d "{\"tenant_id\":\"$TENANT\",\"integration_id\":\"$IID\",\"source_type\":\"MICROSOFT_SENTINEL_V1\",\"fetch_interval_seconds\":900,\"fetch_lookback_window_seconds\":3600}" \
  localhost:8075 nucleus.service.ingestioncontrolservice.IngestionControlService/EnsureIngestionConfiguration
```

Expect JSON with `"ingestionEnabled": true` and a `configurationId`.

## Step 4 — Verify ingestion is flowing

```sh
sleep 12   # Azure auth + first ARM fetch
POD=$(kubectl get pods -o name | grep ingestiongoworker | head -1)
kubectl logs --since=3m "$POD" | grep -iE 'fetched microsoft sentinel incidents|formatted microsoft sentinel batch|wrote batch to storage' | tail -9
DB -c "SELECT lane, response_code, fetch_interval_seconds, fetch_lookback_window_seconds, fetched_at
       FROM ingestion_fetch_tracker WHERE tenant_id='$TENANT' ORDER BY updated_at DESC LIMIT 6;"
```

**Success =** `"fetched microsoft sentinel incidents"` lines, batches written to
`ingestion-batches`, and `response_code 200` for the `hot` lane. A `cold`-lane
`nextLink` 400 (gotcha #6) is a known caveat, not a setup failure.

---

## Re-run / reset notes

- **After `task dev:reset`:** settings are wiped *and* `integration_id` changes —
  re-run from Step 1 (Step 2's live lookup makes it reset-proof).
- **After a `nucleusmanager` redeploy:** only the `:8075` port-forward needs
  re-establishing (Step 0b); config + settings persist in Postgres.
- **ExtraHop** ingestion is analogous: same flow with `source_type=EXTRAHOP_REVEALX_V1`
  and the ExtraHop credential keys — only the credential set and source_type differ.
