---
name: cbq-query
description: Query a Couchbase cluster using SQL++ (formerly N1QL) via the `cbq` shell — delegated to a subagent so multi-hundred-KB result envelopes never enter the main agent's context. Use whenever the user asks to look up, investigate, or query data in Couchbase, run a N1QL/SQL++ query, explore buckets/scopes/collections, inspect documents by key, debug data issues that involve Couchbase, or otherwise needs an answer that requires running SQL++ against a Couchbase cluster — even if they just say "the cluster", "couchbase", or "the documents" without naming the tool. Hard read-only (writes are blocked at the wrapper layer). Handles config-file profile selection, macOS Keychain auth, JSON output parsing, schema discovery via `INFER`, and common gotchas (missing primary index, backtick quoting, 401s).
---

# Couchbase cbq Queries

Run SQL++ (formerly N1QL) against a Couchbase cluster using the bundled `cbq` shell. This skill is generic — the cluster endpoint, username, and Keychain entry are read from a per-user config file. The wrapper script never sees the password directly; it's pulled from macOS Keychain at call time.

## Read-only policy — the most important rule

**This skill performs reads only. Never run a statement that creates, modifies, drops, or deletes anything in the cluster — not "by default", not "unless asked", not ever.** *Primum non nocere.*

Forbidden — refuse, and tell the user this skill is read-only:
- `INSERT`, `UPDATE`, `UPSERT`, `DELETE`, `MERGE`
- Any DDL: `CREATE` (including `CREATE PRIMARY INDEX`), `DROP`, `ALTER`, `TRUNCATE`, `RENAME`, `BUILD INDEX`
- Any permission change: `GRANT`, `REVOKE`
- Anything else that mutates cluster, bucket, scope, collection, document, index, or user state

Allowed:
- `SELECT`, `EXPLAIN`, `INFER`
- `SELECT ... FROM system:*` (read-only catalog queries)

The wrapper script enforces this at runtime: any statement passed via `-script`, `-f`, or stdin that contains a forbidden keyword (outside of string literals, backtick identifiers, or comments) is rejected with exit code 3 before it reaches the cluster. There is no override flag. If the user genuinely needs to write, tell them they must run `cbq` directly outside this skill — do not edit the wrapper to bypass the guard.

If the user asks "can you create an index" / "delete this doc" / "update field X" — answer: "This skill is read-only. You'd need to run that statement against the cluster yourself." Then offer to help them think through the change.

This rule overrides everything else in this document.

## Always run via a subagent

Couchbase result envelopes are often huge. A single `INFER` against a polymorphic bucket easily returns 100–300 KB of nested JSON; `SELECT *` on a collection of fat documents is unbounded; `system:indexes` on a busy cluster can return hundreds of rows. Piping any of that into the main conversation will blow out the context window in one shot, with no way to undo it.

**Therefore: when this skill applies, the main agent must delegate the query work to a subagent (the Agent tool) — do not invoke `scripts/cbq.sh` directly from the main loop.** The subagent runs the queries, writes raw JSON to disk where you can re-read narrow slices on demand, and returns ONLY a concise summary.

This applies even to queries that *look* small ("how many docs in bucket X"). cbq always prints the full request envelope (`requestID`, `signature`, `metrics`, `errors`), and the cluster occasionally returns more than you'd expect. You can't predict the blast radius.

### Subagent prompt template

Dispatch with the Agent tool, `subagent_type: "general-purpose"` (or a project-appropriate subagent if one fits). Use a prompt like:

> Use the cbq-query skill at `~/.claude/skills/cbq-query/` to answer this question: **<user's question, verbatim>**
>
> 1. Read `~/.claude/skills/cbq-query/SKILL.md` and follow its guidance, including the read-only policy.
> 2. Run only the queries needed to answer.
> 3. Save every raw cbq JSON envelope to a file in `/tmp/cbq-<timestamp>-<n>.json` — do NOT include it in your reply.
> 4. Return a concise answer: a bullet list, a small markdown table, or 2–3 sentences. If the answer is a number, give the number. If it's a list, give the list. If the user might want details, name the saved file path.
> 5. Cap your reply at ~300 words. If you can't fit the answer in 300 words, summarize and offer to drill down.

After the subagent returns, relay its summary to the user. If the user asks follow-up questions, dispatch a new subagent or `SendMessage` to the existing one — never run cbq directly.

### When you ARE the dispatched subagent (or the `Agent` tool isn't available)

If you've been spawned to do this work, or you're running in an environment where the `Agent` tool isn't in your toolset, you can't (and shouldn't) re-dispatch. You ARE the read-and-summarize step. Follow the spirit of the rule directly:

1. **Run `scripts/cbq.sh` yourself** — that's why you're here.
2. **Redirect every raw cbq response to a file** (`bash scripts/cbq.sh -script '...' > /tmp/cbq-<step>.json`). Do not let raw envelopes flow back into your own context.
3. **Use `jq` filters on the file** to pull only the specific values, fields, or shapes you need (`jq '.results | length' /tmp/cbq-1.json`, `jq -r '.results[].name' /tmp/cbq-1.json`). Read narrow slices, never the whole envelope.
4. **Return a concise summary** to your caller — bullets, small table, or 2–3 sentences. Name the `/tmp/` path if details might be wanted.

The skill's actual goal is *raw Couchbase JSON never floods a working context*. Once you accept that, the implementation choice (dispatch vs. local-with-jq) follows from your environment. An `INFER` on a fat bucket can return >10 MB; never read that whole thing.

## Usage

```sh
# Single statement against the default profile
bash ~/.claude/skills/cbq-query/scripts/cbq.sh -script 'SELECT "ok" AS ping;'

# A specific profile (when the config defines multiple)
bash ~/.claude/skills/cbq-query/scripts/cbq.sh --profile sandbox -script 'SELECT 1;'

# From a file
bash ~/.claude/skills/cbq-query/scripts/cbq.sh -f path/to/query.n1ql

# From stdin (multi-line via heredoc)
bash ~/.claude/skills/cbq-query/scripts/cbq.sh <<'SQL'
SELECT meta().id, status
FROM `bucket-name`.`scope`.`collection`
WHERE status = "active"
LIMIT 25;
SQL
```

Never run the wrapper with no arguments and no piped stdin — `cbq` will drop into its interactive `cbq>` prompt and hang.

Every flag other than `--profile` is passed straight through to `cbq`, so anything you'd write directly works the same way.

## Setup (first time on a new machine, or for a new cluster)

**Step 1 — Install `cbq` and `jq`.** No need for the full Couchbase Server:

```sh
# cbq (macOS arm64 — swap macos_x86_64 for Intel)
cd ~/Downloads
curl -fLO https://packages.couchbase.com/releases/8.0.0/couchbase-server-dev-tools-8.0.0-macos_arm64.zip
mkdir -p ~/.local/couchbase-tools
unzip -o couchbase-server-dev-tools-8.0.0-macos_arm64.zip -d ~/.local/couchbase-tools/
ln -sf ~/.local/couchbase-tools/couchbase-server-dev-tools-8.0.0-*/bin/cbq ~/.local/bin/cbq

# jq (used by the wrapper to read the config file)
brew install jq
```

**Step 2 — Ask the user for connection details and write the config file.** If you don't already have the user's cluster endpoint and username, ask them — don't guess. Then create `~/.config/cbq-skill/config.json`:

```json
{
  "default": "<profile-name>",
  "profiles": {
    "<profile-name>": {
      "endpoint": "http://<HOST>:8091/",
      "user": "<USERNAME>",
      "keychain_service": "cbq-<HOST>"
    }
  }
}
```

The `keychain_service` is just a label — any unique string works. The convention `cbq-<HOST>` makes it easy to keep separate entries per cluster. You can add more profiles later (`prod`, `sandbox`, …) and switch with `--profile NAME` or `CBQ_PROFILE=NAME`.

**Step 3 — Store the password in macOS Keychain** (the user runs this interactively so the password is never typed in chat or shell history):

```sh
security add-generic-password -a <USERNAME> -s cbq-<HOST> -w
```

The `-w` triggers a hidden interactive prompt for the password.

**Step 4 — Smoke test:**

```sh
bash ~/.claude/skills/cbq-query/scripts/cbq.sh -script 'SELECT "ok" AS ping;'
```

You should see a JSON envelope with `"results": [{"ping": "ok"}]` and `"status": "success"`. If you get a 401, the Keychain entry is wrong. If you get connection refused / timeout, check VPN.

## The single most important rule: discover before you query

The fastest way to give a useless answer is to invent keyspace, scope, collection, or field names. Couchbase identifiers are **case-sensitive** and often contain hyphens (so they need backticks). Before writing the query the user actually wants:

1. **List keyspaces visible to you** with `SELECT * FROM system:keyspaces`. Couchbase organizes data as `bucket.scope.collection`; a "keyspace" in `system:keyspaces` is a fully-qualified `namespace:bucket[.scope.collection]` path.
2. **Infer the shape of a collection** with `INFER` — Couchbase's equivalent of `DESC TABLE`. It samples documents and returns the union of fields with types and frequencies.
3. **Check what indexes exist** in `system:indexes` before writing a filtered query — that often determines whether the predicate is cheap or impossible.
4. **Only after** you've confirmed real names, run the real query.

If the user asks a question where you genuinely don't know which bucket the data lives in, ask before guessing — wrong-bucket queries return convincing-looking but empty/wrong answers.

## Output format

`cbq` returns one JSON envelope per request. The shape is:

```json
{
  "requestID": "...",
  "signature": { "<col>": "<type>" },
  "results": [ { ... }, { ... } ],
  "status": "success",
  "metrics": { "elapsedTime": "...", "resultCount": N, ... }
}
```

For programmatic parsing, pipe through `jq` and grab `.results`:

```sh
bash ~/.claude/skills/cbq-query/scripts/cbq.sh -script '
  SELECT status, COUNT(*) AS n
  FROM `my-bucket`.`_default`.`_default`
  GROUP BY status
  ORDER BY n DESC' | jq '.results'
```

For a single scalar:
```sh
bash ~/.claude/skills/cbq-query/scripts/cbq.sh -script '
  SELECT COUNT(*) AS n FROM `my-bucket`.`_default`.`_default`' \
  | jq -r '.results[0].n'
```

If a query errors, `status` is `errors` and there's an `errors` array with `code` and `msg` — surface those rather than just saying "it failed."

## Rules of engagement

- **Read-only is non-negotiable** — see the top of this file. The wrapper rejects any write/DDL statement before it leaves your machine. Don't try to route around it.
- **Always `LIMIT` exploratory queries** (`LIMIT 100` or smaller). Couchbase will happily stream millions of documents back through the query node and over the wire.
- **Identifiers are case-sensitive and often need backticks.** `_default`, `my-bucket`, `Customers` — wrap in backticks any name with a hyphen, leading underscore, or anything other than `[A-Za-z][A-Za-z0-9_]*`. Single quotes are for string literals.
- **`meta().id` is the document key.** Use it whenever you want to identify or fetch a specific document. `USE KEYS ["key1","key2"]` is the fastest way to fetch documents by key — no index needed.
- **Present small result sets as markdown tables; summarize large ones.** Don't paste the raw `results` JSON back at the user — extract the values.
- **Don't echo customer/PII data verbatim** unless the user explicitly asks for raw rows. Aggregate or redact by default.
- **Never echo credentials, the Keychain output, or the cluster URL with embedded creds** into chat.

## SQL++ vs. SQL — surprises worth knowing

- **No FROM is required** for constant queries: `SELECT 1+1 AS n;` works.
- **`meta()` exposes document metadata**: `meta().id`, `meta().cas`, `meta().expiration`.
- **`OBJECT_*`, `ARRAY_*` functions** reach into nested JSON: `SELECT ARRAY_LENGTH(items) FROM ...`, `SELECT items[0].sku FROM ...`.
- **`UNNEST`** flattens an array field into rows (SQL's `CROSS JOIN UNNEST` / `LATERAL`).
- **`USE KEYS`** is a fast-path lookup bypassing indexes — prefer it when you have document IDs.
- **A query that "needs" a primary index** errors with `No index available on keyspace ...`. Don't blindly create one — that's a cluster-wide write. Instead, restructure to use an existing index (check `system:indexes`) or use `USE KEYS`.

## Schema discovery cheat sheet

```sh
SH=~/.claude/skills/cbq-query/scripts/cbq.sh

# Keyspaces visible to current user (with path = namespace:bucket[.scope.collection])
bash "$SH" -script 'SELECT name, `path` FROM system:keyspaces ORDER BY name'

# Scopes inside a bucket
bash "$SH" -script '
  SELECT name FROM system:scopes
  WHERE `bucket` = "my-bucket" ORDER BY name'

# Collections inside a bucket/scope
bash "$SH" -script '
  SELECT `scope`, name FROM system:keyspaces
  WHERE `bucket` = "my-bucket" ORDER BY `scope`, name'

# Indexes — critical for understanding what queries are cheap
bash "$SH" -script '
  SELECT name, keyspace_id, scope_id, index_key, `condition`, state
  FROM system:indexes ORDER BY keyspace_id, name'

# Shape of a collection (Couchbase's equivalent of DESC TABLE)
bash "$SH" -script '
  INFER `my-bucket`.`_default`.`_default` WITH {"sample_size": 1000}'

# A single document by key — fast, no index needed
bash "$SH" -script '
  SELECT meta().id, * FROM `my-bucket`.`_default`.`_default`
  USE KEYS ["doc::123"]'

# What's the cluster running?
bash "$SH" -script 'SELECT version(), min_version()'
```

## Common gotchas

| Symptom | Cause | Fix |
|---|---|---|
| `No cbq config file at ~/.config/cbq-skill/config.json` | First-time setup not done on this machine | Walk through Setup steps 2–3 |
| `Could not read password from Keychain` | Profile's `keychain_service`/`user` doesn't match an existing entry | `security add-generic-password -a <user> -s <keychain_service> -w` |
| `ERROR 100 : HTTP error 401 Unauthorized` | Wrong/expired creds | Re-add Keychain entry (same command as above) |
| `connection refused` / `dial tcp ...: i/o timeout` | Not on VPN, wrong host, or cluster down | Confirm VPN connectivity and endpoint URL, then retry |
| `No index available on keyspace ...` | Query needs an index Couchbase doesn't have | Use `USE KEYS` if you have doc IDs, or check `system:indexes` for a covering index, or rewrite the predicate to match an existing index. Don't `CREATE PRIMARY INDEX` without asking. |
| `Keyspace not found` on a name you know exists | Missing backticks or wrong case | Quote with backticks; identifiers are case-sensitive |
| Empty results on a `WHERE` you expected to match | Wrong scope/collection, type coercion (string vs. number), or case mismatch on a string filter | Run an unfiltered `SELECT ... LIMIT 3` first to confirm shape, then narrow |
| `cbq` hangs with no output | Invoked without args/stdin — sitting at interactive `cbq>` prompt | Always pass `-script`, `-f`, or pipe via stdin |
| Hyphenated bucket name throws a parse error | Unquoted hyphen treated as minus | Backticks: `` `my-bucket` `` |

## Pattern: discover → query → summarize

The whole skill in one shape:

```sh
SH=~/.claude/skills/cbq-query/scripts/cbq.sh

# 1. What keyspaces can I see?
bash "$SH" -script 'SELECT name FROM system:keyspaces ORDER BY name' | jq -r '.results[].name'

# 2. What does the collection actually look like?
bash "$SH" -script 'INFER `my-bucket`.`_default`.`_default` WITH {"sample_size": 500}' | jq '.results'

# 3. Check what indexes exist before writing a filtered query
bash "$SH" -script '
  SELECT name, index_key, `condition`
  FROM system:indexes
  WHERE keyspace_id = "my-bucket"' | jq '.results'

# 4. Run the actual question, with LIMIT
bash "$SH" -script '
  SELECT status, COUNT(*) AS n
  FROM `my-bucket`.`_default`.`_default`
  WHERE created_at > "2026-04-01"
  GROUP BY status
  ORDER BY n DESC
  LIMIT 50' | jq '.results'

# 5. Summarize for the user as a small markdown table — don't paste raw JSON.
```
