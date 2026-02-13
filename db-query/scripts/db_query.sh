#!/usr/bin/env bash
set -euo pipefail

VAULT_ADDR="https://vault.getbalance.com"
DB_NAME="balancev2"
DB_PORT="5432"
PSQL="/opt/homebrew/opt/libpq/bin/psql"

usage() {
  echo "Usage: $0 <sandbox|prod> <sql_query>"
  echo "Example: $0 sandbox \"SELECT 1\""
  exit 1
}

if [[ $# -lt 2 ]]; then
  usage
fi

ENV="$1"
SQL="$2"

case "$ENV" in
  sandbox)
    VAULT_PATH="sandbox-for-dev/creds/balancev2-ro-one-day"
    DB_HOST="balance-sandbox.cluster-ro-cm9vqarzuodf.us-east-2.rds.amazonaws.com"
    ;;
  prod)
    VAULT_PATH="prod-for-dev/creds/balancev2-ro-one-day"
    DB_HOST="balance-prod.cluster-ro-cm9vqarzuodf.us-east-2.rds.amazonaws.com"
    ;;
  *)
    echo "Error: environment must be 'sandbox' or 'prod'" >&2
    exit 1
    ;;
esac

# Validate GITHUB_TOKEN
if [[ -z "${GITHUB_TOKEN:-}" ]]; then
  echo "Error: GITHUB_TOKEN environment variable is not set" >&2
  exit 1
fi

# Check vault CLI
if ! command -v vault &>/dev/null; then
  echo "vault CLI not found. Installing via brew (hashicorp/tap)..." >&2
  brew tap hashicorp/tap && brew install hashicorp/tap/vault
fi

# Authenticate to Vault via GitHub
export VAULT_ADDR
VAULT_TOKEN=$(vault login -method=github -token-only token="$GITHUB_TOKEN" 2>/dev/null)
export VAULT_TOKEN

# Get dynamic DB credentials
CREDS_JSON=$(vault read -format=json "$VAULT_PATH" 2>/dev/null)
DB_USER=$(echo "$CREDS_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['username'])")
DB_PASS=$(echo "$CREDS_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['password'])")

# Run query via psql
PGPASSWORD="$DB_PASS" "$PSQL" \
  -h "$DB_HOST" \
  -p "$DB_PORT" \
  -U "$DB_USER" \
  -d "$DB_NAME" \
  --no-psqlrc \
  -c "$SQL"
