---
name: debug
description: Systematic debugging approach for tracking down issues - use when encountering bugs, errors, or unexpected behavior
---

# Systematic Debugging

A structured methodology for finding and fixing bugs efficiently.

## Step 1: Reproduce the Issue

Before anything else, reliably reproduce the problem.

```
Questions to answer:
- What are the exact steps to trigger the bug?
- Does it happen every time or intermittently?
- What environment? (OS, browser, versions, config)
- What's the expected behavior vs actual behavior?
```

**If you can't reproduce it, you can't verify you've fixed it.**

## Step 2: Gather Information

Collect all available evidence before forming hypotheses.

### Error Messages & Stack Traces
- Read the **entire** error message, not just the first line
- Identify the originating file and line number
- Note the call stack - where did execution come from?

### Logs
```bash
# Check application logs
tail -f logs/app.log

# Check system logs
journalctl -f -u myservice

# Filter for errors
grep -i "error\|exception\|fail" logs/*.log
```

### State Inspection
- What are the variable values at the point of failure?
- What's in the database/cache/session?
- What requests/responses are being sent?

## Step 3: Form Hypotheses

Based on evidence, list possible causes ranked by likelihood:

```
1. [Most likely] Input validation missing for edge case
2. [Likely] Race condition in async code
3. [Possible] Stale cache returning old data
4. [Unlikely] Third-party API behavior changed
```

## Step 4: Isolate with Binary Search

Narrow down the problem space systematically.

### In Code
- Comment out half the suspect code - does it still fail?
- Add logging at midpoints to find where state goes wrong
- Use git bisect to find the breaking commit:
  ```bash
  git bisect start
  git bisect bad HEAD
  git bisect good v1.2.0
  # Git will checkout commits for you to test
  ```

### In Data
- Does it fail with minimal input?
- Does it work with known-good data?
- Which specific field/value causes the issue?

## Step 5: Check Recent Changes

Bugs often come from recent modifications.

```bash
# What changed recently?
git log --oneline -20

# What files were modified?
git diff HEAD~5 --stat

# Who touched this file?
git blame src/problem-file.ts

# When did this line change?
git log -p -S "problematic code" -- src/
```

## Step 6: Common Bug Patterns

### Off-by-One Errors
- Array indices: 0-based vs 1-based
- Loop boundaries: `<` vs `<=`
- String slicing: inclusive vs exclusive end

### Null/Undefined
- Missing null checks
- Optional chaining needed: `obj?.property`
- Default values: `value ?? defaultValue`

### Async Issues
- Missing `await`
- Race conditions
- Callback not called / called multiple times
- Promise rejection not handled

### State Issues
- Stale closures capturing old values
- Mutating shared state
- Cache invalidation problems

### Type Coercion
- `==` vs `===`
- String vs number comparisons
- Truthy/falsy edge cases (`0`, `""`, `[]`)

## Step 7: Debugging Tools

### Print Debugging
Simple but effective:
```javascript
console.log('>>> checkpoint 1', { variable, state });
```

### Interactive Debuggers
- Set breakpoints at suspicious locations
- Step through execution line by line
- Inspect variables and call stack
- Watch expressions

### Network Debugging
```bash
# Watch HTTP traffic
curl -v https://api.example.com/endpoint

# Check what's actually being sent
tcpdump -i any port 443
```

## Step 8: Verify the Fix

Before considering it solved:

1. **Confirm the fix** - Does the original reproduction case pass?
2. **Test edge cases** - What about related scenarios?
3. **Check for regressions** - Did you break anything else?
4. **Write a test** - Prevent this bug from returning

## Debugging Mindset

- **Don't assume** - Verify every assumption
- **Read the code** - What does it actually do, not what you think it does
- **Question everything** - Even "working" code nearby
- **Take breaks** - Fresh eyes find bugs faster
- **Rubber duck** - Explain the problem out loud

## When You're Stuck

1. Step away for 15 minutes
2. Explain the problem to someone (or a rubber duck)
3. Re-read the documentation for involved APIs
4. Search for the exact error message
5. Create a minimal reproduction case
6. Ask for help with specific details
