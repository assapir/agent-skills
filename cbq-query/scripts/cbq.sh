#!/usr/bin/env bash
# cbq.sh — read-only wrapper around the Couchbase `cbq` SQL++ shell.
#
# This wrapper is policy-enforced read-only: any statement containing
# INSERT/UPDATE/UPSERT/DELETE/MERGE/CREATE/DROP/ALTER/TRUNCATE/GRANT/REVOKE
# (outside string literals, backtick identifiers, or comments) is rejected
# before it reaches the cluster. There is no escape hatch — if a write is
# genuinely needed, invoke cbq directly outside this skill.
#
# Usage:
#   cbq.sh [--profile NAME] -script 'SELECT ...;'
#   cbq.sh [--profile NAME] -f path/to/query.n1ql
#   echo 'SELECT 1;' | cbq.sh [--profile NAME]
#
# Connection details are resolved from a JSON config file (default
# ~/.config/cbq-skill/config.json, override with $CBQ_CONFIG):
#
#   {
#     "default": "myprofile",
#     "profiles": {
#       "myprofile": {
#         "endpoint": "http://HOST:8091/",
#         "user": "USERNAME",
#         "keychain_service": "cbq-SOMETHING"
#       }
#     }
#   }
#
# Password is fetched at run time from macOS Keychain:
#   security find-generic-password -a <user> -s <keychain_service> -w
# Store it once with:
#   security add-generic-password -a <user> -s <keychain_service> -w

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK_READONLY="$SCRIPT_DIR/check_readonly.py"
CONFIG_FILE="${CBQ_CONFIG:-$HOME/.config/cbq-skill/config.json}"

# ---- Argument parsing: pull out --profile; collect SQL text from -script / -f ----
profile_arg=""
remaining_args=()
sql_chunks=()

i=1
argv=("$@")
n=$#
while [ "$i" -le "$n" ]; do
    arg="${argv[$((i-1))]}"
    case "$arg" in
        --profile)
            [ "$i" -lt "$n" ] || { echo "ERROR: --profile needs a value" >&2; exit 2; }
            profile_arg="${argv[$i]}"
            i=$((i+2))
            ;;
        --profile=*)
            profile_arg="${arg#--profile=}"
            i=$((i+1))
            ;;
        -script|--script)
            [ "$i" -lt "$n" ] || { echo "ERROR: -script needs a value" >&2; exit 2; }
            sql_chunks+=("${argv[$i]}")
            remaining_args+=("$arg" "${argv[$i]}")
            i=$((i+2))
            ;;
        -script=*|--script=*)
            sql_chunks+=("${arg#*=}")
            remaining_args+=("$arg")
            i=$((i+1))
            ;;
        -f|--f|-file|--file)
            [ "$i" -lt "$n" ] || { echo "ERROR: $arg needs a value" >&2; exit 2; }
            file_path="${argv[$i]}"
            if [ -f "$file_path" ]; then
                sql_chunks+=("$(cat "$file_path")")
            fi
            remaining_args+=("$arg" "$file_path")
            i=$((i+2))
            ;;
        -f=*|--f=*|-file=*|--file=*)
            file_path="${arg#*=}"
            if [ -f "$file_path" ]; then
                sql_chunks+=("$(cat "$file_path")")
            fi
            remaining_args+=("$arg")
            i=$((i+1))
            ;;
        *)
            remaining_args+=("$arg")
            i=$((i+1))
            ;;
    esac
done

# ---- Capture stdin (if piped) so we can both inspect and forward it ----
stdin_text=""
if [ ! -t 0 ]; then
    stdin_text="$(cat)"
fi

# ---- Read-only guard: scan all SQL we can see ----
combined=""
for chunk in ${sql_chunks[@]+"${sql_chunks[@]}"}; do
    combined+="$chunk"$'\n'
done
combined+="$stdin_text"

if [ -n "${combined//[[:space:]]/}" ]; then
    if ! command -v python3 >/dev/null 2>&1; then
        echo "ERROR: python3 is required for the read-only guard." >&2
        exit 127
    fi
    forbidden=$(printf '%s' "$combined" | python3 "$CHECK_READONLY" || true)
    if [ -n "$forbidden" ]; then
        cat >&2 <<EOF
ERROR: cbq-query skill is READ-ONLY by policy. Statement rejected.
  Forbidden keyword(s) detected: $forbidden
  Allowed: SELECT, EXPLAIN, INFER, and SELECT ... FROM system:*
If a write is genuinely required, run cbq directly outside this skill.
EOF
        exit 3
    fi
fi

# ---- Resolve config + creds ----
command -v cbq >/dev/null 2>&1 || {
    echo "ERROR: cbq not found on PATH. See SKILL.md for installation." >&2
    exit 127
}

command -v jq >/dev/null 2>&1 || {
    echo "ERROR: jq is required (used to read the config file). Install with: brew install jq" >&2
    exit 127
}

if [ ! -f "$CONFIG_FILE" ]; then
    cat >&2 <<EOF
ERROR: No cbq config file at $CONFIG_FILE.

Create one with at least one profile, then re-run. Minimal example:

  mkdir -p "$(dirname "$CONFIG_FILE")"
  cat > "$CONFIG_FILE" <<'JSON'
  {
    "default": "myprofile",
    "profiles": {
      "myprofile": {
        "endpoint": "http://HOST:8091/",
        "user": "USERNAME",
        "keychain_service": "cbq-HOST"
      }
    }
  }
  JSON

Then store the password in macOS Keychain (prompted interactively):
  security add-generic-password -a USERNAME -s cbq-HOST -w
EOF
    exit 1
fi

profile="${profile_arg:-${CBQ_PROFILE:-}}"
if [ -z "$profile" ]; then
    profile="$(jq -r '.default // empty' "$CONFIG_FILE")"
    if [ -z "$profile" ]; then
        echo "ERROR: No profile specified and no \"default\" set in $CONFIG_FILE." >&2
        echo "Pass --profile NAME or set CBQ_PROFILE; profiles available: $(jq -r '.profiles | keys | join(", ")' "$CONFIG_FILE")" >&2
        exit 1
    fi
fi

endpoint="$(jq -r --arg p "$profile" '.profiles[$p].endpoint // empty' "$CONFIG_FILE")"
user="$(jq -r --arg p "$profile" '.profiles[$p].user // empty' "$CONFIG_FILE")"
keychain_service="$(jq -r --arg p "$profile" '.profiles[$p].keychain_service // empty' "$CONFIG_FILE")"

if [ -z "$endpoint" ] || [ -z "$user" ] || [ -z "$keychain_service" ]; then
    echo "ERROR: profile '$profile' in $CONFIG_FILE must define endpoint, user, and keychain_service." >&2
    echo "Profiles available: $(jq -r '.profiles | keys | join(", ")' "$CONFIG_FILE")" >&2
    exit 1
fi

password="$(security find-generic-password -a "$user" -s "$keychain_service" -w 2>/dev/null)" || {
    echo "ERROR: Could not read password from Keychain." >&2
    echo "  profile = $profile" >&2
    echo "  account (-a) = $user" >&2
    echo "  service (-s) = $keychain_service" >&2
    echo "Set it once: security add-generic-password -a '$user' -s '$keychain_service' -w" >&2
    exit 1
}

# ---- Exec cbq, forwarding stdin if we captured any ----
if [ -n "$stdin_text" ]; then
    printf '%s' "$stdin_text" | cbq -e "$endpoint" -u "$user" -p "$password" ${remaining_args[@]+"${remaining_args[@]}"}
else
    exec cbq -e "$endpoint" -u "$user" -p "$password" ${remaining_args[@]+"${remaining_args[@]}"}
fi
