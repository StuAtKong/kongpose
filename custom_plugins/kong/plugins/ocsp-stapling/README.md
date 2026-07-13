# ocsp-stapling

> **PROOF OF CONCEPT — UNSUPPORTED.** This is a custom plugin, NOT officially
> supported by Kong Inc. Use at your own risk in production environments.

Staples OCSP responses for certificates served **dynamically** by Kong —
i.e. `certificate` + `sni` entities added via the Admin API (or decK).

## Why this exists

Kong serves dynamic certificates through `ssl_certificate_by_lua`, which
bypasses nginx's native `ssl_stapling` machinery — that only works for
certificates configured statically in `kong.conf` (`ssl_cert` /
`KONG_SSL_CERT`). The result: any cert loaded through the Admin API is
served **without** an OCSP staple, even with `nginx_proxy_ssl_stapling=on`.

This plugin closes that gap using OpenResty's `ngx.ocsp` API. It also
improves on two properties of nginx's native stapling:

| | nginx native stapling | this plugin |
|---|---|---|
| Covers Admin API certs | no | yes |
| Cache scope | per worker process | per node (shared dict) |
| First handshake stapled | no (lazy fetch) | yes (startup pre-warm; inline fetch as fallback) |

## How it works

Per TLS handshake, in the `certificate` phase:

1. Resolve the client's SNI to a Kong certificate entity — exact match
   first, then leftmost-label wildcard (`proxy.example.com` →
   `*.example.com`). No match means Kong is serving its static default
   cert, which nginx staples natively; the plugin steps aside.
2. Serve the OCSP response from the shared-dict cache when present.
3. On a cold cache, build an OCSP request from the cert chain, POST it to
   the responder URL from the certificate's AIA extension, validate the
   response, cache it, and staple it — all within the same handshake.
4. Once 75% of `cache_ttl` has elapsed, handshakes keep serving the cached
   response while a single background timer refreshes it, so warm traffic
   never pays responder latency.

All failures are **fail-open**: the handshake completes without a staple
and the reason is logged. Nothing is ever blocked.

### Cache behavior in detail

- **Pre-warmed at startup.** Shortly after a node starts (~5s, retrying
  while a hybrid DP is still syncing config), one worker sweeps all
  non-wildcard SNIs and fetches their staples, logging a summary
  (`OCSP prewarm done: N stapled, …`). The first real handshake is served
  from cache; the inline fetch only remains as a fallback for SNIs added
  after startup or behind wildcards. Disable with
  `config.prewarm=false`.
- **Bounded by the response's own validity.** The plugin parses the OCSP
  response's `nextUpdate` (via libcrypto FFI) and never serves it beyond
  that — an expired staple is worse than none. Within that bound the
  response is kept as **stale-if-error** headroom: if background
  refreshes fail, the last good response keeps being stapled until it
  genuinely expires, rather than falling off a cliff at `cache_ttl`.
  If `nextUpdate` can't be parsed, the fallback stale window is
  `2 * cache_ttl`.
- **Failures are negative-cached.** A failed fetch (unreachable
  responder, validation failure, missing issuer, …) is recorded for
  `failure_ttl` seconds; during that window handshakes for the SNI
  proceed unstapled immediately — no added latency, and the responder
  isn't hammered by every handshake.
- **Entity changes purge immediately.** The plugin listens for
  certificate/SNI CRUD events and drops the affected cache entries (a
  changed wildcard SNI or certificate purges everything, since affected
  concrete names can't be enumerated). TTLs are only the fallback bound —
  a rotated cert gets a fresh staple on the next handshake. On hybrid
  data planes this relies on incremental sync (`cluster_incremental_sync`)
  or the declarative reconfigure event for full sync.

## Requirements

- The certificate entity's `cert` field must contain the **full chain**
  (leaf + intermediate). The issuer certificate is required to build the
  OCSP request; a leaf-only PEM fails with
  `failed to create OCSP request` — unless trust anchors are configured
  (`config.ca_certificates` or `config.trusted_certificate`) and contain
  the issuer (see [Response validation](#response-validation)).
- The data plane must be able to reach the OCSP responder over HTTP
  (outbound, usually port 80).
- Must be enabled **globally** — the `certificate` phase runs before any
  route/service is known, so only global plugins execute. The schema
  enforces this.

## Installation

The plugin ships as plain Lua files, loaded via `lua_package_path`
(already wired up in this repo — see `KONG_LUA_PACKAGE_PATH` and the
`./custom_plugins` volume mount in `docker-compose.yaml`):

```yaml
KONG_LUA_PACKAGE_PATH: "/usr/local/custom_plugins/?.lua;;"
KONG_PLUGINS: "bundled, ocsp-stapling"
```

Set both on the **control plane and data plane** in hybrid mode, then
restart. Enable it globally:

```bash
curl -X POST http://localhost:8001/plugins \
  -H "kong-admin-token: $KONG_ADMIN_TOKEN" \
  -d "name=ocsp-stapling"
```

## Configuration

| field | type | default | description |
|---|---|---|---|
| `config.prewarm` | boolean | `true` | Fetch staples for all non-wildcard SNIs at startup so the first handshake is served from cache. |
| `config.cache_ttl` | number | `3600` | Refresh interval: a background refresh triggers at 75% of this. The response itself is served until its own `nextUpdate` (see [Cache behavior](#cache-behavior-in-detail)). |
| `config.http_timeout` | number | `5000` | Timeout (ms) for the HTTP request to the OCSP responder. |
| `config.failure_ttl` | number | `30` | Seconds a fetch failure is negative-cached; during this window handshakes for that SNI go unstapled without re-contacting the responder. |
| `config.cert_cache_ttl` | number | `300` | Seconds the SNI→certificate DB lookup is cached. Bounds how quickly a rotated certificate picks up a fresh staple. |
| `config.shm_name` | string | `"kong"` | Name of the `lua_shared_dict` used to cache OCSP responses. Must exist in the nginx config; if it doesn't, stapling is disabled (fail-open) and an error is logged once per worker. |
| `config.ca_certificates` | array of UUIDs | (unset) | IDs of Kong `ca_certificates` entities used as trust anchors when validating OCSP responses — the preferred mechanism. See [Response validation](#response-validation). |
| `config.trusted_certificate` | string | (unset) | Inline PEM alternative/addition to `ca_certificates`. Kept for anchors that aren't CA certs (e.g. a delegated responder cert) and quick tests. |

### Response validation

By default, an OCSP response is validated against **the chain stored in
the certificate entity itself** — self-consistent, but not checked
against an independent trust store.

Configuring trust anchors switches to nginx-equivalent strictness
(`ssl_trusted_certificate` + `ssl_stapling_verify on`): responses are
validated against *leaf + your anchors*, ignoring any intermediates
bundled in the entity. A response that doesn't verify against them is
rejected (`OCSP_basic_verify() failed` in the error log) and the
handshake proceeds unstapled.

The preferred way is referencing Kong's first-class `ca_certificates`
entities by ID — the same convention as `mtls-auth` — so the CA is
stored once and rotating it is an entity update, not a config hunt:

```bash
# one entity per CA cert (ca_certificates entities hold a single cert)
CA_ID=$(curl -s -X POST http://localhost:8001/ca_certificates \
  -H "kong-admin-token: $KONG_ADMIN_TOKEN" \
  --data-urlencode "cert@intermediate.pem" | jq -r .id)

curl -X PATCH http://localhost:8001/plugins/<plugin-id> \
  -H "kong-admin-token: $KONG_ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"config\":{\"ca_certificates\":[\"$CA_ID\"]}}"
```

`config.trusted_certificate` accepts an inline PEM bundle instead (or in
addition — the two are combined). Unlike `ca_certificates` entities,
which must be actual CA certs (`CA:TRUE`), the inline PEM can hold any
trust anchor, e.g. a delegated OCSP responder certificate.

Either form also acts as an **issuer fallback**: if a certificate entity
contains only the leaf (no intermediate), the issuer needed to build the
OCSP request is taken from the anchors instead — relaxing the full-chain
requirement below for certs covered by them.

A dangling `ca_certificates` ID is treated as a fetch failure (fail-open,
logged, negative-cached) rather than silently validating against fewer
anchors than configured. Updating or deleting a referenced
`ca_certificates` entity purges cached responses immediately (CRUD
events); changing the plugin's own config does not — that applies from
the next fetch.

### Using a dedicated shared dict

The default uses Kong's general-purpose `kong` dict. OCSP responses are
~1–2 KB each, so with many certificates a dedicated dict is cleaner:

```yaml
KONG_NGINX_HTTP_LUA_SHARED_DICT: "ocsp_stapling 5m"
```

```bash
curl -X PATCH http://localhost:8001/plugins/<plugin-id> \
  -H "kong-admin-token: $KONG_ADMIN_TOKEN" \
  -d "config.shm_name=ocsp_stapling"
```

## Verifying

Load a cert with a live OCSP responder and an SNI, then check the staple
(run against the proxy port — `8443` via ha-proxy in this repo, which is
TCP passthrough to the DP):

```bash
echo | openssl s_client -connect localhost:8443 \
  -servername kong-proxy.heronwood.co.uk -status 2>/dev/null \
  | sed -n '/OCSP response/,/Next Update/p'
```

Expected when working:

```
OCSP Response Status: successful (0x0)
Cert Status: good
Next Update: <timestamp>
```

`OCSP response: no response sent` means no staple — check the DP error
log, all plugin failures are logged with the SNI and reason:

```bash
docker logs kongpose-kong-dp-1 2>&1 | grep ocsp-stapling
```

## Testing

A [Pongo](https://github.com/Kong/kong-pongo) test suite lives in
`spec/` next to this README, with the rockspec Pongo needs at the
`custom_plugins/` root:

```bash
cd custom_plugins
KONG_VERSION=3.10.0.6 pongo up
KONG_VERSION=3.10.0.6 pongo run -- kong/plugins/ocsp-stapling/spec
```

The version must be one Pongo supports (`pongo build` prints the list on
a mismatch); there is no CE `3.10.x`, so the Enterprise `3.10.0.6` —
matching this repo's gateway image — is the validated pin.

- `01-schema_spec.lua` — config schema: defaults, bounds, UUID
  validation for `ca_certificates`.
- `02-integration_spec.lua` — fail-open paths against a real Kong:
  handshake completes unstapled when the cert has no AIA, fetch failures
  are negative-cached (a 3-handshake burst logs exactly one fetch error),
  wildcard SNI resolution, and stepping aside for unknown SNIs.
- `03-responder_spec.lua` — happy path against a **mock OCSP responder**
  (an `http_mock` fixture serving a pre-signed, long-lived response on
  the port the test leaf's AIA points at; the plugin sends no nonce, so
  a canned response validates): startup pre-warm, a `Cert Status: good`
  staple on the first handshake, cache hits on subsequent handshakes,
  the background refresh after the fresh window elapses (`cache_ttl=1`),
  and strict-validation rejection when `ca_certificates` references the
  wrong CA. Staple assertions shell out to the `openssl` CLI and are
  skipped if it's missing.

The embedded fixtures (test CA, leaf, canned response) are valid until
2036+; regenerate with `openssl` if they ever expire.

## Limitations

- Wildcard SNI matching is leftmost-label only (`*.example.com`); Kong's
  rightmost wildcards (`example.*`) are not matched. Wildcard SNIs are
  also not pre-warmed — the concrete hostnames aren't known until a
  client presents one, so their first handshake fetches inline.
- A responder outage on a cold cache means unstapled handshakes until the
  responder recovers (fail-open by design; retried at most once per
  `failure_ttl`). There is no persistent cache across restarts.
- No support for OCSP `Must-Staple` certificates' hard-fail semantics —
  the plugin never rejects a handshake.
- HTTP-subsystem only. The stream subsystem (`stream_listen`) has no
  `ngx.ocsp` API; TLS streams are served without staples.
- The plugin trusts the responder URL in the certificate's AIA extension
  and fetches over plain HTTP (standard for OCSP; responses are signed).
- **Security:** because the responder URL comes from the certificate
  itself, anyone who can create certificate entities can make data
  planes POST to arbitrary URLs, including internal ones — an SSRF
  vector where Admin API access is delegated (RBAC, multi-team).
  Restrict who may manage certificates; an `allowed_responders`
  allowlist would be a sensible hardening step before production use.
- Plugin **config** changes (e.g. `trusted_certificate`, `cache_ttl`) do
  not purge already-cached responses; they take effect on the next fetch.
  Certificate/SNI/`ca_certificates` **entity** changes do purge
  immediately (CRUD events).

## Files

- `handler.lua` — certificate-phase logic: SNI resolution, OCSP fetch,
  shared-dict caching, background refresh.
- `schema.lua` — plugin config schema (global-only, `https` protocol).
- `spec/` — Pongo test suite (see [Testing](#testing)).
