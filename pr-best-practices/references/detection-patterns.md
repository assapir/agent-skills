# Tooling Detection Patterns

Comprehensive patterns for detecting and using repo-specific tooling.

## Package Manager Detection (JavaScript/TypeScript)

### Priority Order

Always check in this order - the first match wins:

1. **yarn.lock** → Yarn
2. **pnpm-lock.yaml** → pnpm
3. **package-lock.json** → npm
4. **No lock file** → Ask user or check for `.npmrc`/`.yarnrc`

### Commands by Package Manager

| Operation | npm | yarn | pnpm |
|-----------|-----|------|------|
| Run script | `npm run <script>` | `yarn <script>` | `pnpm <script>` |
| Install deps | `npm install` | `yarn` | `pnpm install` |
| Add dep | `npm install <pkg>` | `yarn add <pkg>` | `pnpm add <pkg>` |
| Add dev dep | `npm install -D <pkg>` | `yarn add -D <pkg>` | `pnpm add -D <pkg>` |

### Common Scripts to Check

```json
{
  "scripts": {
    "lint": "...",
    "lint:fix": "...",
    "format": "...",
    "fmt": "...",
    "check": "...",
    "typecheck": "...",
    "type-check": "...",
    "test": "...",
    "test:unit": "...",
    "test:e2e": "...",
    "build": "...",
    "prepare": "..."
  }
}
```

## Makefile Detection

### Common Targets

```makefile
# Linting
lint:
check:

# Formatting
fmt:
format:

# Testing
test:
tests:
test-unit:
test-integration:

# Building
build:
compile:

# All checks (often combines lint + test)
all:
ci:
```

### Detection Method

```bash
# List available targets
make -qp 2>/dev/null | grep -E '^[a-zA-Z_-]+:' | cut -d: -f1
```

## Pre-commit Hooks

### Detection

Check for `.pre-commit-config.yaml` in repo root.

### Automatic Execution

**Pre-commit hooks run automatically on `git commit`** - no manual intervention needed. The hooks will check staged files before allowing the commit.

### Manual Commands (rarely needed)

```bash
# Run all hooks on all files (useful for initial setup or CI)
pre-commit run --all-files

# Run on specific files
pre-commit run --files path/to/file1 path/to/file2

# Run specific hook
pre-commit run <hook-id> --all-files
```

### Common Hook IDs

- `trailing-whitespace`
- `end-of-file-fixer`
- `check-yaml`
- `check-json`
- `black` (Python)
- `ruff` (Python)
- `eslint` (JavaScript)
- `prettier` (JavaScript)

## Python Projects

### Tool Detection Matrix

| Check For | Tool | Lint Command | Format Command |
|-----------|------|--------------|----------------|
| `ruff.toml` | Ruff | `ruff check .` | `ruff format .` |
| `[tool.ruff]` in pyproject.toml | Ruff | `ruff check .` | `ruff format .` |
| `[tool.black]` in pyproject.toml | Black | N/A | `black .` |
| `[tool.isort]` in pyproject.toml | isort | N/A | `isort .` |
| `[tool.mypy]` in pyproject.toml | mypy | `mypy .` | N/A |
| `[tool.pytest]` in pyproject.toml | pytest | N/A | N/A |
| `pytest.ini` | pytest | N/A | N/A |
| `setup.cfg` with `[flake8]` | flake8 | `flake8` | N/A |
| `.flake8` | flake8 | `flake8` | N/A |
| `tox.ini` | tox | `tox -e lint` | N/A |

### Test Running

```bash
# Run all tests
pytest

# Run specific file
pytest tests/test_module.py

# Run tests matching pattern
pytest -k "test_function_name"

# Run tests in directory
pytest tests/unit/
```

### Virtual Environment / Package Manager Detection

Check for (in priority order):
- `uv.lock` → use `uv run` (fast, modern package manager)
- `poetry.lock` → use `poetry run`
- `Pipfile.lock` → use `pipenv run`
- `.venv/` or `venv/` directory → activate or use direct path

## Go Projects

### Detection

Check for `go.mod` in repo root.

### Commands

```bash
# Format
go fmt ./...

# Lint
go vet ./...

# Additional linting (if installed)
golangci-lint run

# Test all
go test ./...

# Test specific package
go test ./pkg/mypackage/...

# Test with coverage
go test -cover ./...
```

## Rust Projects

### Detection

Check for `Cargo.toml` in repo root.

### Commands

```bash
# Format check
cargo fmt --check

# Format fix
cargo fmt

# Lint
cargo clippy

# Lint with warnings as errors
cargo clippy -- -D warnings

# Test all
cargo test

# Test specific
cargo test test_name

# Build check
cargo check
```

## Ruby Projects

### Detection Matrix

| File | Tool | Commands |
|------|------|----------|
| `Gemfile` | Bundler | `bundle exec <cmd>` |
| `.rubocop.yml` | RuboCop | `rubocop`, `rubocop -a` |
| `Rakefile` | Rake | `rake test`, `rake spec` |
| `.rspec` | RSpec | `rspec` |

## PHP Projects

### Detection Matrix

| File | Tool | Commands |
|------|------|----------|
| `composer.json` | Composer | `composer run <script>` |
| `phpunit.xml` | PHPUnit | `./vendor/bin/phpunit` |
| `.php-cs-fixer.php` | PHP-CS-Fixer | `./vendor/bin/php-cs-fixer fix` |
| `phpstan.neon` | PHPStan | `./vendor/bin/phpstan analyse` |

## CI Configuration Files

These files indicate what CI checks are run:

| File | CI System |
|------|-----------|
| `.github/workflows/*.yml` | GitHub Actions |
| `.gitlab-ci.yml` | GitLab CI |
| `.circleci/config.yml` | CircleCI |
| `Jenkinsfile` | Jenkins |
| `.travis.yml` | Travis CI |
| `azure-pipelines.yml` | Azure DevOps |
| `bitbucket-pipelines.yml` | Bitbucket Pipelines |

Reading CI config helps understand what checks must pass.

## Editor/IDE Config (Hints)

These files hint at project tooling:

| File | Indicates |
|------|-----------|
| `.editorconfig` | Formatting preferences |
| `.prettierrc*` | Prettier for JS/TS |
| `.eslintrc*` | ESLint for JS/TS |
| `tsconfig.json` | TypeScript project |
| `biome.json` | Biome for JS/TS |
| `deno.json` | Deno project |

## Detection Priority

When multiple tools exist, prefer:

1. **Project-specific config** over global
2. **Lock file indicated tool** over alternatives
3. **CI-validated tools** over local-only
4. **Newer tools** over legacy (e.g., Ruff over flake8+black)

## Running Checks

### General Strategy

1. Check for Makefile first (often wraps other tools)
2. Check for package.json scripts
3. Check for language-specific tools
4. Fall back to individual tool detection

### Example Detection Flow

```
1. Does Makefile exist?
   YES → Check for lint/fmt/test targets
   NO → Continue

2. Does package.json exist?
   YES → Detect package manager, check scripts
   NO → Continue

3. Does pyproject.toml exist?
   YES → Check for ruff/black/pytest config
   NO → Continue

4. Does go.mod exist?
   YES → Use go fmt/vet/test
   NO → Continue

5. Does Cargo.toml exist?
   YES → Use cargo fmt/clippy/test
   NO → Continue

6. Check for pre-commit config
   YES → Run pre-commit
   NO → Manual tool detection
```
