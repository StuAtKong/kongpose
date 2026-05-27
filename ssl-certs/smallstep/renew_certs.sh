#!/usr/bin/env bash
#
# Regenerate the Kong demo certificate hierarchy using smallstep's step-cli.
#
# Generates everything kongpose actually consumes:
#   - root_ca.pem / .key             (self-signed)
#   - intermediate_ca1.pem / .key    (signed by root)
#   - intermediate_ca2.pem / .key    (signed by int1)
#   - kong.lan.pem / .key            (CN=manager.kong.lan + SANs for admin/portal/api/proxy)
#   - wild.kong.lan.pem / .key       (CN=*.kong.lan — used by keycloak, solace)
#   - client.kong.lan.pem / .key     (mTLS client cert)
#   - client/mtls-consumer.kong.lan.pem / .key  (mTLS consumer cert)
#   - combined-wild.pem              (chain bundle for HAproxy)
#
# Renewal logic: if kong.lan.pem is valid for more than GRACE_DAYS, exit. Otherwise
# regenerate any CA whose own grace period has lapsed, then regenerate every leaf.
#
# Run from anywhere — the script self-locates to ssl-certs/smallstep/.

set -euo pipefail

cd "$(dirname "$0")"

# ──────────────── Configuration ────────────────

STEP_IMAGE="smallstep/step-cli:0.28.6"   # pin for reproducibility; bump deliberately

GRACE_DAYS=30                            # treat anything expiring within N days as "needs renewal"

# step-cli's --not-after uses Go duration syntax (h/m/s only — no "d"), so express in hours.
ROOT_CA_HOURS=87600                       # 10y (3650d)
INT1_CA_HOURS=43800                       # 5y  (1825d)
INT2_CA_HOURS=26280                       # 3y  (1095d)
LEAF_HOURS=8760                           # 1y  (365d)

# Domains to cover. The first one is the "primary" (used for CNs); every domain
# listed here is added to the SAN list of the primary and wildcard certs, so a
# single cert serves all of them.
DOMAINS=(kong.lan kong.com)

# Subdomain prefixes the kong.lan-style leaf cert serves on (per domain).
KONG_PREFIXES=(manager api portal portal-api proxy)

# Extra SANs attached to every leaf cert. step-cli auto-detects DNS vs IP.
EXTRA_SANS=(127.0.0.1)

# Build the primary CN + SAN list from the configuration above.
PRIMARY_CN="${KONG_PREFIXES[0]}.${DOMAINS[0]}"

PRIMARY_SANS=()
for domain in "${DOMAINS[@]}"; do
    for prefix in "${KONG_PREFIXES[@]}"; do
        PRIMARY_SANS+=("${prefix}.${domain}")
    done
    PRIMARY_SANS+=("$domain")
done
PRIMARY_SANS+=("${EXTRA_SANS[@]}")

# ──────────────── Pre-flight ────────────────

command -v docker  >/dev/null || { echo "ERROR: docker not found"; exit 1; }
command -v openssl >/dev/null || { echo "ERROR: openssl not found (needed for expiry check)"; exit 1; }

HOST_UID=$(id -u)
HOST_GID=$(id -g)

run_step() {
    docker run --rm \
        --user "${HOST_UID}:${HOST_GID}" \
        -v "$PWD:/app" \
        -w /app \
        "$STEP_IMAGE" "$@"
}

# Returns 0 if file is missing or will expire within GRACE_DAYS, 1 otherwise.
needs_renewal() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        return 0
    fi
    local seconds=$((GRACE_DAYS * 24 * 60 * 60))
    if openssl x509 -in "$file" -checkend "$seconds" -noout &>/dev/null; then
        return 1
    fi
    return 0
}

# ──────────────── Short-circuit if nothing needs doing ────────────────

if ! needs_renewal kong.lan.pem; then
    expiry=$(openssl x509 -in kong.lan.pem -enddate -noout | cut -d= -f2)
    echo "kong.lan.pem is valid until $expiry (more than ${GRACE_DAYS}d away). Nothing to do."
    exit 0
fi

echo "==> kong.lan.pem missing or near expiry — starting renewal"

# ──────────────── Backup ────────────────

BACKUP_DIR="../.cert-backup-$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"
shopt -s nullglob
backup_files=(*.pem *.key client/*.pem client/*.key)
if (( ${#backup_files[@]} > 0 )); then
    cp -p "${backup_files[@]}" "$BACKUP_DIR/" 2>/dev/null || true
    echo "    backed up existing certs to $BACKUP_DIR"
fi
shopt -u nullglob

# ──────────────── Templates ────────────────
# Step CLI templates that pin maxPathLen for the 3-level CA hierarchy.
# Without these, intermediate2 may not be permitted to sign leaves.

write_template_if_missing() {
    local path="$1" body="$2"
    if [[ ! -f "$path" ]]; then
        printf '%s\n' "$body" > "$path"
        echo "    wrote template $path"
    fi
}

# Build root.tpl dynamically so its nameConstraints stay in sync with $DOMAINS.
# nameConstraints (critical) limits the entire chain to issue certs only for
# the listed DNS suffixes and IP ranges — even if root_ca.pem is imported into
# an OS truststore, it can't be abused to sign for arbitrary domains.
write_root_template() {
    local permitted_dns="" first=1
    for d in "${DOMAINS[@]}"; do
        if (( first )); then permitted_dns="\"$d\""; first=0
        else permitted_dns="$permitted_dns, \"$d\""
        fi
    done

    local new_content
    new_content=$(cat <<EOF
{
    "subject": {{ toJson .Subject }},
    "issuer": {{ toJson .Subject }},
    "keyUsage": ["certSign", "crlSign"],
    "basicConstraints": {
        "isCA": true,
        "maxPathLen": 2
    },
    "nameConstraints": {
        "critical": true,
        "permittedDNSDomains": [${permitted_dns}],
        "permittedIPRanges": ["127.0.0.0/8", "::1/128"]
    }
}
EOF
)

    if [[ -f root.tpl ]] && [[ "$(cat root.tpl)" == "$new_content" ]]; then
        return
    fi

    if [[ -f root_ca.pem ]]; then
        echo "    WARNING: root.tpl changed (DOMAINS updated?) — existing root_ca.pem"
        echo "             does NOT reflect new constraints. Delete root_ca.pem (and"
        echo "             the intermediate CAs) and re-run to regenerate the chain."
    fi

    printf '%s\n' "$new_content" > root.tpl
    echo "    wrote root.tpl with nameConstraints for: ${DOMAINS[*]}"
}

write_root_template

write_template_if_missing intermediate1.tpl '{
    "subject": {{ toJson .Subject }},
    "keyUsage": ["certSign", "crlSign"],
    "basicConstraints": {
        "isCA": true,
        "maxPathLen": 1
    }
}'

write_template_if_missing intermediate2.tpl '{
    "subject": {{ toJson .Subject }},
    "keyUsage": ["certSign", "crlSign"],
    "basicConstraints": {
        "isCA": true,
        "maxPathLen": 0
    }
}'

# ──────────────── CA hierarchy ────────────────

if needs_renewal root_ca.pem; then
    echo "==> generating Root CA"
    run_step step certificate create "Demo Kong Root CA" \
        /app/root_ca.pem /app/root_ca.key \
        --template /app/root.tpl \
        --not-after "${ROOT_CA_HOURS}h" \
        --no-password --insecure --force
fi

if needs_renewal intermediate_ca1.pem; then
    echo "==> generating Intermediate CA 1"
    run_step step certificate create "Demo Kong Intermediate1 CA" \
        /app/intermediate_ca1.pem /app/intermediate_ca1.key \
        --template /app/intermediate1.tpl \
        --ca /app/root_ca.pem --ca-key /app/root_ca.key \
        --not-after "${INT1_CA_HOURS}h" \
        --no-password --insecure --force
fi

if needs_renewal intermediate_ca2.pem; then
    echo "==> generating Intermediate CA 2"
    run_step step certificate create "Demo Kong Intermediate2 CA" \
        /app/intermediate_ca2.pem /app/intermediate_ca2.key \
        --template /app/intermediate2.tpl \
        --ca /app/intermediate_ca1.pem --ca-key /app/intermediate_ca1.key \
        --not-after "${INT2_CA_HOURS}h" \
        --no-password --insecure --force
fi

# ──────────────── Leaf certs ────────────────

# Generate a leaf signed by Intermediate CA 2.
# The CN is auto-included as a SAN (modern TLS clients ignore CN and only
# match against SANs). Duplicate SANs are de-duped so callers can pass the
# CN explicitly without producing a bad cert.
# Args: <cn> <cert-path> <key-path> [san1 san2 ...]
generate_leaf() {
    local cn="$1" cert_path="$2" key_path="$3"
    shift 3

    local -A seen=()
    local unique_sans=()
    local s
    for s in "$cn" "$@"; do
        if [[ -z "${seen[$s]:-}" ]]; then
            seen[$s]=1
            unique_sans+=("$s")
        fi
    done

    local args=(
        "$cn"
        "/app/$cert_path"
        "/app/$key_path"
        --profile leaf
        --ca /app/intermediate_ca2.pem
        --ca-key /app/intermediate_ca2.key
        --not-after "${LEAF_HOURS}h"
        --no-password --insecure --force
    )
    for s in "${unique_sans[@]}"; do
        args+=(--san "$s")
    done
    run_step step certificate create "${args[@]}"
}

echo "==> generating kong.lan.* (Admin/Manager/Portal/Proxy)"
generate_leaf "$PRIMARY_CN" kong.lan.pem kong.lan.key "${PRIMARY_SANS[@]}"

echo "==> generating wild.kong.lan.* (wildcard, used by keycloak/solace)"
WILDCARD_SANS=()
for domain in "${DOMAINS[@]}"; do
    WILDCARD_SANS+=("*.${domain}")
done
WILDCARD_SANS+=("${EXTRA_SANS[@]}")
generate_leaf "*.${DOMAINS[0]}" wild.kong.lan.pem wild.kong.lan.key "${WILDCARD_SANS[@]}"

echo "==> generating client.kong.lan.* (mTLS client)"
generate_leaf "client.${DOMAINS[0]}" client.kong.lan.pem client.kong.lan.key "${EXTRA_SANS[@]}"

echo "==> generating client/mtls-consumer.kong.lan.* (mTLS consumer)"
mkdir -p client
generate_leaf "mtls-consumer" client/mtls-consumer.kong.lan.pem client/mtls-consumer.kong.lan.key "${EXTRA_SANS[@]}"

# ──────────────── HAproxy bundle ────────────────

echo "==> building combined-wild.pem for HAproxy"
cat wild.kong.lan.pem intermediate_ca2.pem intermediate_ca1.pem root_ca.pem wild.kong.lan.key \
    > combined-wild.pem

# ──────────────── Permissions ────────────────
# step writes keys at 0600. Kong runs as non-root inside the container and the host
# uid differs from the container uid, so the simplest portable fix is world-readable
# 0644 on these demo files. See README.md "HACK Alert" — this is dev-only.

chmod 644 *.pem *.key
if compgen -G "client/*" > /dev/null; then
    chmod 644 client/*.pem client/*.key
fi

# ──────────────── Summary ────────────────

echo ""
echo "Renewal complete."
echo ""
echo "Generated files:"
ls -lh root_ca.pem intermediate_ca1.pem intermediate_ca2.pem \
       kong.lan.pem kong.lan.key \
       wild.kong.lan.pem wild.kong.lan.key \
       client.kong.lan.pem client.kong.lan.key \
       combined-wild.pem 2>/dev/null
if [[ -d client ]]; then
    echo ""
    ls -lh client/*.pem client/*.key 2>/dev/null || true
fi

leaf_expiry=$(openssl x509 -in kong.lan.pem -enddate -noout | cut -d= -f2)
echo ""
echo "kong.lan leaf expires: $leaf_expiry"
echo "Backup of previous certs: $BACKUP_DIR"
echo ""
# ──────────────── Restart cert-consuming containers ────────────────
# Restart only services that are actually running so we don't error on stopped
# profile-gated ones (keycloak, solace).

CERT_CONSUMERS=(kong-cp kong-dp ha-proxy keycloak solace)
running_consumers=()
if running_list=$(cd ../.. && docker compose ps --services --status running 2>/dev/null); then
    for svc in "${CERT_CONSUMERS[@]}"; do
        if grep -qxF "$svc" <<<"$running_list"; then
            running_consumers+=("$svc")
        fi
    done
fi

if (( ${#running_consumers[@]} == 0 )); then
    echo "No cert-consuming services are currently running. Start the stack with 'docker compose up'."
elif [[ -t 0 ]]; then
    read -rp "Restart [${running_consumers[*]}] to pick up new certs? [Y/n] " answer
    answer="${answer:-Y}"
    if [[ "$answer" =~ ^[Yy] ]]; then
        (cd ../.. && docker compose restart "${running_consumers[@]}")
    else
        echo "Skipped. Restart manually with: docker compose restart ${running_consumers[*]}"
    fi
else
    echo "Non-interactive shell; skipping auto-restart. Run manually:"
    echo "    docker compose restart ${running_consumers[*]}"
fi

echo ""
echo "Don't forget: your OS/browser must trust root_ca.pem (see ssl-certs/README.md)."
