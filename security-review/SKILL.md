---
name: security-review
description: Review code for security vulnerabilities including OWASP top 10, injection flaws, authentication issues, and data exposure
---

# Security Review Checklist

Systematic security review based on OWASP Top 10 and common vulnerability patterns.

## OWASP Top 10 (2021)

### A01: Broken Access Control

**Check for:**
- [ ] Authorization checked on every request, not just UI
- [ ] Users cannot access other users' data by changing IDs
- [ ] Admin functions protected server-side
- [ ] CORS configured restrictively
- [ ] Directory listing disabled
- [ ] JWT tokens validated properly (signature, expiry, issuer)

**Red flags:**
```javascript
// BAD: Only checking in UI
if (user.isAdmin) showAdminButton();

// BAD: Trusting client-provided user ID
const userId = req.body.userId;
return db.getUser(userId);
```

### A02: Cryptographic Failures

**Check for:**
- [ ] Sensitive data encrypted at rest
- [ ] TLS used for all data in transit
- [ ] Strong algorithms (AES-256, bcrypt, argon2)
- [ ] No hardcoded secrets or keys
- [ ] Passwords hashed, not encrypted
- [ ] No sensitive data in URLs or logs

**Red flags:**
```javascript
// BAD: Weak hashing
const hash = md5(password);

// BAD: Hardcoded secret
const JWT_SECRET = "super-secret-key";

// BAD: Sensitive data in URL
redirect(`/reset?token=${token}&email=${email}`);
```

### A03: Injection

**Check for:**
- [ ] Parameterized queries for SQL
- [ ] Input sanitization for NoSQL
- [ ] Command arguments escaped/validated
- [ ] LDAP queries parameterized
- [ ] XPath queries parameterized

**Red flags:**
```javascript
// BAD: SQL injection
db.query(`SELECT * FROM users WHERE id = ${userId}`);

// BAD: Command injection
exec(`convert ${filename} output.png`);

// BAD: NoSQL injection
db.users.find({ username: req.body.username });
```

**Fix:**
```javascript
// GOOD: Parameterized query
db.query('SELECT * FROM users WHERE id = ?', [userId]);

// GOOD: Validated input
if (!/^[a-zA-Z0-9]+$/.test(filename)) throw new Error('Invalid');
```

### A04: Insecure Design

**Check for:**
- [ ] Rate limiting on sensitive operations
- [ ] Account lockout after failed attempts
- [ ] Business logic abuse prevention
- [ ] Threat modeling performed
- [ ] Security requirements defined

### A05: Security Misconfiguration

**Check for:**
- [ ] Default credentials changed
- [ ] Unnecessary features disabled
- [ ] Error messages don't leak info
- [ ] Security headers set (CSP, X-Frame-Options, etc.)
- [ ] Debug mode disabled in production
- [ ] Directory permissions restrictive

**Required headers:**
```
Content-Security-Policy: default-src 'self'
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
Strict-Transport-Security: max-age=31536000
X-XSS-Protection: 1; mode=block
```

### A06: Vulnerable Components

**Check for:**
- [ ] Dependencies up to date
- [ ] No known vulnerabilities (CVEs)
- [ ] Components from trusted sources
- [ ] Unused dependencies removed

**Commands:**
```bash
# JavaScript
npm audit
npx npm-check-updates

# Python
pip-audit
safety check

# Go
go list -m all | nancy sleuth

# General
trivy fs .
```

### A07: Authentication Failures

**Check for:**
- [ ] Strong password requirements enforced
- [ ] Multi-factor authentication available
- [ ] Session tokens rotated after login
- [ ] Secure session storage (httpOnly, secure, sameSite)
- [ ] Logout invalidates session server-side
- [ ] Password reset tokens expire quickly

**Red flags:**
```javascript
// BAD: Weak session cookie
res.cookie('session', token);

// GOOD: Secure cookie
res.cookie('session', token, {
  httpOnly: true,
  secure: true,
  sameSite: 'strict',
  maxAge: 3600000
});
```

### A08: Software and Data Integrity

**Check for:**
- [ ] Dependencies verified (checksums, signatures)
- [ ] CI/CD pipeline secured
- [ ] Unsigned code rejected
- [ ] Deserialization of untrusted data avoided

**Red flags:**
```javascript
// BAD: Deserializing user input
const obj = JSON.parse(userInput);
eval(obj.code);

// BAD: Dynamic require
require(userProvidedPath);
```

### A09: Logging & Monitoring Failures

**Check for:**
- [ ] Authentication events logged
- [ ] Access control failures logged
- [ ] Input validation failures logged
- [ ] Logs don't contain sensitive data
- [ ] Logs are tamper-evident
- [ ] Alerting configured for suspicious activity

**Never log:**
- Passwords or secrets
- Full credit card numbers
- Session tokens
- Personal health information
- Social security numbers

### A10: Server-Side Request Forgery (SSRF)

**Check for:**
- [ ] User-provided URLs validated
- [ ] Internal network access blocked
- [ ] URL schemes restricted (no file://, gopher://)
- [ ] Redirects don't bypass validation

**Red flags:**
```javascript
// BAD: Fetching user-provided URL
const response = await fetch(req.body.url);

// GOOD: Validate and restrict
const url = new URL(req.body.url);
if (!['https:'].includes(url.protocol)) throw new Error('Invalid');
if (isPrivateIP(url.hostname)) throw new Error('Invalid');
```

---

## Input Validation

### General Rules
- Validate on server side (client validation is UX only)
- Whitelist allowed values, don't blacklist bad ones
- Validate type, length, format, and range
- Reject invalid input, don't try to sanitize

### Common Patterns
```javascript
// Email
/^[^\s@]+@[^\s@]+\.[^\s@]+$/

// UUID
/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

// Alphanumeric
/^[a-zA-Z0-9]+$/

// URL (use URL constructor, not regex)
try { new URL(input); } catch { /* invalid */ }
```

---

## Secrets Management

**Never commit:**
- API keys
- Database passwords
- Private keys
- JWT secrets
- OAuth client secrets

**Check for secrets in:**
```bash
# Search for potential secrets
grep -r "password\|secret\|api_key\|token" --include="*.js" .
grep -r "-----BEGIN" .

# Use tools
gitleaks detect
trufflehog git file://.
```

**Proper storage:**
- Environment variables
- Secret managers (Vault, AWS Secrets Manager)
- Encrypted config files (not in repo)

---

## Quick Security Checklist

Before merging any PR:

- [ ] No hardcoded secrets
- [ ] SQL queries parameterized
- [ ] User input validated
- [ ] Authorization checked server-side
- [ ] Sensitive data not logged
- [ ] Dependencies have no critical CVEs
- [ ] Error messages don't leak internal info
- [ ] File uploads validated and sandboxed
- [ ] Rate limiting on authentication endpoints
