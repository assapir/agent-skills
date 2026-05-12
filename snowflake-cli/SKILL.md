---
name: snowflake-cli
description: Query Snowflake from the command line using `snow sql`. Use whenever the user asks to look up data in Snowflake, run a SQL query against a Snowflake warehouse, explore Snowflake schemas/tables, debug data issues that involve Snowflake, or otherwise needs an answer that requires running SQL against Snowflake — even if they say "the data warehouse" or "snow" without naming Snowflake explicitly. Handles output formats, schema discovery, connection switching, and common gotchas (warehouse suspended, role lacking grants, default db/schema).
---

# Snowflake CLI Queries

Run SQL against Snowflake using the `snow` CLI.

## Setup (first time on a new machine)

If `snow --version` already works and `snow connection list` shows a `default` connection, skip this section.

1. **Install the Snowflake CLI.** Pick one:
   ```sh
   brew install snowflake-cli           # macOS, recommended
   pipx install snowflake-cli           # cross-platform
   ```
   Official docs: https://docs.snowflake.com/en/developer-guide/snowflake-cli/installation/installation

2. **Create `~/.snowflake/connections.toml`** with the connection block below. Replace `<ORG>-<ACCOUNT>` with the account identifier from Snowsight → Account Details and `<sso-email>` with the SSO email:
   ```toml
   [default]
   account = "<ORG>-<ACCOUNT>"
   user = "<sso-email>"
   authenticator = "externalbrowser"
   warehouse = "COMPUTE_WH"
   role = "PUBLIC"
   database = "NSURE_DATA"
   client_store_temporary_credential = true
   ```
   The last line caches the SSO token so the browser doesn't pop on every query.

3. **Test the connection** — this triggers the SSO browser flow once:
   ```sh
   snow connection test -c default
   ```

After setup, `~/.snowflake/connections.toml` holds a `default` connection authenticated via SSO (`externalbrowser`) and pointed at database `NSURE_DATA`. When the user asks ambiguously "what tables do we have" or "find the X table", start exploration there before asking which database they mean.

The default role is `PUBLIC`. On this account `PUBLIC` does have read access to `NSURE_DATA` (including `INFORMATION_SCHEMA`), so the great majority of queries work without switching role. Don't switch role preemptively — the cost of a wrong role hypothesis is wasted commands and confusion. Try the query first under the current role. Only consider `--role ENGINEER` (or another role) when you see one of these *empirical* signals:

- `SHOW DATABASES` itself returns empty rows — that genuinely means no grants.
- A query errors with `Object does not exist or not authorized` on a name you have other evidence exists.

An empty result from a *filtered* query like `SHOW TABLES LIKE '%foo%'` or a `WHERE` clause on `INFORMATION_SCHEMA.TABLES` is **not** evidence of a permissions problem — it just means nothing matched that filter. Broaden the pattern, search other schemas, or try a different keyword before reaching for `--role`. The single biggest source of waste in early iterations of this skill was treating "no match" as "no access."

## The single most important rule: discover before you query

The fastest way to give a useless answer is to invent table or column names. Before writing the query the user actually wants:

1. If the user names a table you don't already know exists, run `SHOW TABLES IN SCHEMA ...` or `SHOW TABLES LIKE '...' IN DATABASE ...` first.
2. If the user names a column you don't know, run `DESC TABLE <db>.<schema>.<table>` first.
3. Only after you've confirmed the real names, run the query.

This costs one extra round-trip and prevents the embarrassing "Object does not exist" loop. If the user asks a question where you genuinely don't know which database/schema the data lives in, ask before guessing — Snowflake accounts often have many databases and the wrong one returns convincing-looking but wrong answers.

## Running queries

### Single query
```sh
snow sql -q "SELECT CURRENT_USER(), CURRENT_ROLE(), CURRENT_WAREHOUSE()"
```

### From a file
```sh
snow sql -f path/to/query.sql
```

### From stdin (multi-line via heredoc)
```sh
snow sql -i <<'SQL'
SELECT id, status
FROM <db>.<schema>.<table>
WHERE created_at > DATEADD(day, -7, CURRENT_DATE)
LIMIT 50;
SQL
```

### Override connection / role / warehouse / database / schema for a single call
```sh
snow sql -q "..." -c default --role ENGINEER --warehouse COMPUTE_WH --database <DB> --schema <SCHEMA>
```
Only `--connection` has a short flag (`-c`). The rest are long-flag only.

## Output formats

`snow` prints a TABLE by default. For programmatic parsing prefer JSON, then pipe through `jq`:

```sh
snow sql --format JSON -q "SELECT 1 AS n, 'hi' AS s" | jq .
```

Supported `--format` values: `TABLE`, `JSON`, `JSON_EXT`, `CSV`. **`--format` is a flag on `sql`, not a global flag — put it *after* `sql`**. Placing it before `sql` errors with `No such option: --format`. Wide tables wrap badly in TABLE format; switch to CSV for those.

```sh
snow sql --format CSV -q "..." > out.csv
```

To extract a single scalar:
```sh
snow sql --format JSON -q "SELECT COUNT(*) AS n FROM <db>.<schema>.<table>" | jq -r '.[0].N'
```
(Snowflake upper-cases unquoted identifiers, so JSON keys come back as `N`, not `n`.)

## Rules of engagement

- **Default to read-only `SELECT` / `SHOW` / `DESC` / `EXPLAIN`.** If the user asks for `INSERT`/`UPDATE`/`DELETE`/`CREATE`/`DROP`/`ALTER`/`MERGE`/`TRUNCATE`, confirm intent and target before running. The current role probably can't do these anyway, but don't rely on permissions as a safety net.
- **Always `LIMIT` exploratory queries** (`LIMIT 100` or smaller). Snowflake bills compute time on the warehouse — don't dump millions of rows.
- **Snowflake folds unquoted identifiers to UPPER.** `SELECT id FROM Orders` is identical to `SELECT ID FROM ORDERS`. Quote with double quotes only when the actual name has lowercase or special characters. Single quotes are for string literals.
- **Present results as small markdown tables** when there are <20 rows; **summarize key findings** for larger result sets. Don't paste the full ASCII `+---+` art back to the user — extract the actual values.
- **Don't paste apparent customer/PII data into chat verbatim.** Aggregate or redact. If the user explicitly asks for raw rows, fine — but default to summaries.
- **Never echo credentials, account identifiers, tokens, or the contents of `~/.snowflake/connections.toml`** into chat.

## Schema discovery cheat sheet

```sh
# Databases visible to current role
snow sql -q "SHOW DATABASES"

# Schemas in a database
snow sql -q "SHOW SCHEMAS IN DATABASE <DB>"

# Tables / views in a schema
snow sql -q "SHOW TABLES IN SCHEMA <DB>.<SCHEMA>"
snow sql -q "SHOW VIEWS IN SCHEMA <DB>.<SCHEMA>"

# Find a table whose name you only half-remember
snow sql -q "SHOW TABLES LIKE '%order%' IN DATABASE <DB>"

# Columns of a table (two equivalent ways)
snow sql -q "DESC TABLE <DB>.<SCHEMA>.<TABLE>"
snow sql -q "
  SELECT column_name, data_type, is_nullable
  FROM <DB>.INFORMATION_SCHEMA.COLUMNS
  WHERE table_schema = '<SCHEMA>' AND table_name = '<TABLE>'
  ORDER BY ordinal_position
"

# What's my session?
snow sql -q "SELECT CURRENT_ROLE(), CURRENT_WAREHOUSE(), CURRENT_DATABASE(), CURRENT_SCHEMA()"

# Which roles can I assume?
snow sql -q "SELECT CURRENT_AVAILABLE_ROLES()"

# Which warehouses can I see?
snow sql -q "SHOW WAREHOUSES"
```

## Connection management

```sh
snow connection list                 # see all configured connections
snow connection test -c default      # smoke test (opens browser if no cached token)
snow connection set-default <name>   # pick which connection is used when -c is omitted
```

Connection file: `~/.snowflake/connections.toml`. Schema:

```toml
[default]
account = "<ORG>-<ACCOUNT>"          # e.g. ETMZUSX-LW98386
user = "<sso-email>"
authenticator = "externalbrowser"
warehouse = "COMPUTE_WH"
role = "PUBLIC"
database = "NSURE_DATA"              # default DB so unqualified table refs resolve here
# Optional:
# schema = "<SCHEMA>"
# client_store_temporary_credential = true   # cache SSO token so the browser doesn't pop every command
```

## Common gotchas

| Symptom | Cause | Fix |
|---|---|---|
| `Could not use warehouse "X". Object does not exist, or operation cannot be performed` | User's default warehouse isn't visible to the current role | Pass `--warehouse COMPUTE_WH` (or another visible WH) on the command, or set `warehouse = "COMPUTE_WH"` in the connection block |
| `Object does not exist or not authorized` on a real table | Wrong role, missing grants, or unqualified name | Check `SELECT CURRENT_ROLE()`. Try the fully-qualified `DB.SCHEMA.TABLE`. Try a more privileged role with `--role`. |
| Empty `SHOW DATABASES` output | Role grants nothing | Switch role (`--role ENGINEER`/`ANALYST` etc.). |
| Empty `SHOW TABLES LIKE` or filtered `INFORMATION_SCHEMA` query | Pattern didn't match — **not** a permissions issue if the database itself is visible | Broaden the LIKE pattern, try other schemas, check spelling. Do not switch role. |
| Browser doesn't open for SSO | Missing or misspelled `authenticator` | `authenticator = "externalbrowser"` — exact spelling |
| Browser opens for every query | SSO token isn't cached | Add `client_store_temporary_credential = true` to the connection block |
| 404 on `<X>.snowflakecomputing.com` during connect | Account identifier wrong (using legacy locator without region) | Use the org-account form `<ORG>-<ACCOUNT>` (visible in Snowsight → Account Details) |
| Hangs ~30s with no output | Warehouse is suspended and resuming | Wait — first query after a pause warms the warehouse |
| `Unsupported feature 'PIVOT_OF_VIEW'` etc. | Feature not on this Snowflake edition | Rewrite without it |

## Pattern: discover → query → summarize

The whole skill in one shape:

```sh
# 1. Discover what databases the role can see
snow sql -q "SHOW DATABASES"

# 2. Find the table the user is asking about
snow sql -q "SHOW TABLES LIKE '%order%' IN DATABASE <DB>"

# 3. Inspect its schema
snow sql -q "DESC TABLE <DB>.<SCHEMA>.<TABLE>"

# 4. Run the actual question, with LIMIT
snow sql -q "
  SELECT status, COUNT(*) AS n
  FROM <DB>.<SCHEMA>.<TABLE>
  WHERE created_at > DATEADD(day, -7, CURRENT_DATE)
  GROUP BY status
  ORDER BY n DESC
  LIMIT 50
"

# 5. Summarize for the user — don't paste the full ASCII table back.
```
