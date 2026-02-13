---
name: db-query
description: Query the Balance prod or sandbox PostgreSQL database. Use when the user asks to look up, investigate, or query data in the database, check DB state, debug data issues, or needs information that requires SQL queries. Handles Vault authentication and credential retrieval automatically.
---

# DB Query

Run read-only SQL queries against the Balance prod or sandbox PostgreSQL database. Credentials are fetched automatically from HashiCorp Vault using the `GITHUB_TOKEN` env var.

## Usage

```bash
bash /Users/asapir/.claude/skills/db-query/scripts/db_query.sh <sandbox|prod> "<SQL query>"
```

## Rules

- Default to **sandbox** unless the user explicitly says "prod" or "production"
- Before querying **prod**, warn the user and confirm they want prod
- Only run **SELECT** queries (credentials are read-only)
- For schema discovery, query `information_schema.tables` and `information_schema.columns`
- Present results in a clean, readable format (use markdown tables for small result sets)
- For large result sets, summarize key findings rather than dumping raw output

## Examples

```bash
# List tables
bash /Users/asapir/.claude/skills/db-query/scripts/db_query.sh sandbox "SELECT table_name FROM information_schema.tables WHERE table_schema='public' ORDER BY table_name"

# Describe a table
bash /Users/asapir/.claude/skills/db-query/scripts/db_query.sh sandbox "SELECT column_name, data_type, is_nullable FROM information_schema.columns WHERE table_name='orders' ORDER BY ordinal_position"

# Query data
bash /Users/asapir/.claude/skills/db-query/scripts/db_query.sh sandbox "SELECT id, status, created_at FROM orders WHERE buyer_id = '123' ORDER BY created_at DESC LIMIT 10"
```

## Troubleshooting

- **"GITHUB_TOKEN not set"**: The env var must be exported in the shell
- **"vault CLI not found"**: The script auto-installs via `brew install vault`
- **Permission denied on Vault**: The GitHub token may lack access to the requested environment
- **Connection timeout**: Check network/VPN connectivity to AWS RDS
