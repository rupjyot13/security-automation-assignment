# Security Findings

## 1. Executive Overview

Security analysis identified several weaknesses in the VulnTracker application and its dependencies. The most significant application-level risks were SQL injection, broken object-level authorization, sensitive password information being written to logs, and acceptance of the JWT `none` algorithm. These issues could allow unauthorized data access, manipulation of application behavior, authentication bypass, or exposure of credentials.

The dependency analysis also identified multiple vulnerable Python and Node.js packages. Container and Infrastructure-as-Code analysis are addressed after the production container and infrastructure configuration are created in Task 4.

---

# 2. SAST Findings

## 2.1 SQL Injection

**Scan type:** SAST  
**Tool:** Bandit + manual code review  
**Severity:** High  
**Origin:** Starter repository

### Finding

The scan-search functionality originally constructed SQL using direct string interpolation of user-controlled input.

The vulnerable pattern was equivalent to:

```python
f"... WHERE title LIKE '%{query}%' ..."
```

This allowed the search input to become part of the SQL statement.

### Business impact

An attacker able to access the search functionality could potentially manipulate the SQL query and access or influence database information beyond the intended search operation.

Because the application contains scan results and security-related information, unauthorized database access could expose vulnerability findings and other application data.

### Remediation

The SQL query was changed to use a parameterized SQL statement:

```python
WHERE title LIKE :search
   OR description LIKE :search
   OR cve_id LIKE :search
```

The search value is supplied separately as a SQL parameter.

**Status: Remediated**

---

## 2.2 Broken Object-Level Authorization / IDOR

**Scan type:** Manual security review  
**Severity:** High  
**Origin:** Starter repository

### Finding

The original `GET /scans/{scan_id}` endpoint retrieved a scan using only the supplied scan ID and did not verify that the authenticated user owned the requested scan.

### Business impact

An authenticated user who knows or guesses another scan's ID could potentially access another user's scan results.

This could expose security findings, CVE information, affected components, descriptions, and ownership information.

### Remediation

The scan lookup was changed to require both:

```python
models.ScanResult.id == scan_id
```

and:

```python
models.ScanResult.owner_id == current_user.id
```

Therefore, a user can retrieve only scans belonging to that user.

**Status: Remediated**

---

## 2.3 Passwords Written to Logs

**Scan type:** Manual security review  
**Severity:** High  
**Origin:** Starter repository

### Finding

The original login implementation included the user's password in authentication log messages.

### Business impact

Application logs are frequently stored, copied, aggregated, or accessed by operations and monitoring systems. Passwords written to logs could therefore be exposed to anyone with access to application logs.

An exposed password could also be reused against other services if users reuse credentials.

### Remediation

Password values were removed from authentication log messages.

The login logging now records the username without recording the password.

**Status: Remediated**

---

## 2.4 JWT `none` Algorithm Acceptance

**Scan type:** Manual security review  
**Severity:** High  
**Origin:** Starter repository

### Finding

The original JWT verification configuration explicitly allowed both the configured signing algorithm and the `none` algorithm.

### Business impact

Allowing an unsigned JWT algorithm can create an authentication bypass risk if an attacker can submit a token accepted without a valid cryptographic signature.

Successful exploitation could allow unauthorized access to protected application endpoints.

### Remediation

JWT decoding was changed to allow only the configured signing algorithm:

```python
jwt.decode(
    token,
    SECRET_KEY,
    algorithms=[ALGORITHM],
)
```

The explicit `none` algorithm was removed.

**Status: Remediated**

---

## 2.5 Hardcoded JWT Secret

**Scan type:** SAST — Bandit  
**Severity:** High  
**Origin:** Starter repository

### Finding

Bandit identified a hardcoded JWT secret in `app/config.py`.

### Business impact

If the source repository or application package is exposed, an attacker could obtain the signing secret and potentially create forged authentication tokens.

### Remediation status

**Not remediated in Task 3.**

The finding is documented in `docs/remediation-plan.md`.

---

## 2.6 Hardcoded Database Password

**Scan type:** SAST — Bandit  
**Severity:** High  
**Origin:** Starter repository

### Finding

A database password is stored directly in `app/config.py`.

### Business impact

Exposure of the source code could expose database credentials. If the credentials are valid against a reachable database, unauthorized database access could occur.

### Remediation status

**Not remediated in Task 3.**

The finding is documented in `docs/remediation-plan.md`.

---

## 2.7 Bandit `bearer` Finding

**Scan type:** SAST — Bandit  
**Severity:** Low according to tool  
**Classification:** False positive

Bandit reported the string `"bearer"` as a possible hardcoded password.

The occurrence is part of the HTTP authentication scheme used by the API and is not a secret or credential.

**Status: False positive — no remediation required**

---

# 3. Python Dependency Analysis

**Scan type:** SCA / dependency analysis  
**Tool:** pip-audit  
**Source:** `requirements.txt`

The dependency scan identified vulnerabilities in several Python packages.

## 3.1 `python-jose`

**Severity:** High

Known advisories include JWT-related vulnerabilities such as algorithm confusion and denial-of-service issues.

This dependency is particularly relevant because the application uses it for JWT authentication.

**Origin:** Starter dependency

**Status:** Not remediated in Task 3.

---

## 3.2 `cryptography`

**Severity:** High overall dependency risk

Multiple security advisories were identified for the installed version.

The exact exploitability depends on which cryptographic functionality is exercised by the application.

**Origin:** Starter dependency

**Status:** Not remediated in Task 3.

---

## 3.3 `starlette`

**Severity:** High overall dependency risk

The installed Starlette version has multiple security advisories affecting areas including request processing, form handling, and other framework functionality.

**Origin:** Starter dependency

**Status:** Not remediated in Task 3.

---

## 3.4 `python-multipart`

**Severity:** High overall dependency risk

Multiple advisories were reported, including denial-of-service and request-processing issues.

Exploitability is dependent on application use of multipart/form functionality. The current application primarily uses JSON request bodies.

**Origin:** Starter dependency

**Status:** Not remediated in Task 3.

---

## 3.5 `fastapi`

**Severity:** Medium / context-dependent

The installed FastAPI version was associated with a vulnerability involving request/form processing through the underlying multipart functionality.

The application primarily uses JSON requests, reducing exposure to some affected functionality.

**Origin:** Starter dependency

**Status:** Not remediated in Task 3.

---

## 3.6 `ecdsa`

**Severity:** Low / context-dependent

A timing-related vulnerability was reported for the installed version.

The application's JWT configuration uses HS256 rather than ECDSA-based signing, so the reported issue is not directly exercised by the current authentication implementation.

**Origin:** Starter dependency

**Status:** Not remediated in Task 3.

---

## 3.7 `pytest`

**Severity:** Low

A vulnerability was reported in the test dependency.

This package is used for testing rather than production application execution.

**Origin:** Starter dependency

**Status:** Not remediated in Task 3.

---

# 4. Node.js Dependency Analysis

**Scan type:** SCA / dependency analysis  
**Source:** `notify/package-lock.json`

The Node.js dependency assessment identified vulnerabilities in direct and transitive dependencies.

## 4.1 Axios

**Severity:** High

The installed Axios dependency has multiple reported security issues involving areas such as SSRF, request handling, denial of service, and other security weaknesses.

Because Axios is a direct dependency of the notification service, it should be upgraded and regression-tested.

**Origin:** Starter dependency

**Status:** Not remediated in Task 3.

---

## 4.2 Express and Transitive Dependencies

**Severity:** High

The Express dependency chain contains reported vulnerabilities involving packages such as:

- `body-parser`
- `path-to-regexp`
- `qs`
- `send`
- `serve-static`
- `cookie`

The findings include denial-of-service, request-processing, redirect, and related issues.

These are consolidated under the Express dependency chain rather than treated as separate application vulnerabilities.

**Origin:** Starter dependency

**Status:** Not remediated in Task 3.

---

## 4.3 UUID

**Severity:** Moderate

The installed `uuid` version has a reported security issue affecting certain buffer-handling scenarios.

**Origin:** Starter dependency

**Status:** Not remediated in Task 3.

---

# 5. Container Image Analysis

**Scan type:** Container image security scan

The final container scan was deferred because the starter repository did not contain the production Dockerfile required to build the final application image.

Task 4 will create the production-grade container image.

The resulting image should then be scanned for:

- Operating-system vulnerabilities
- Library vulnerabilities
- Insecure configuration
- Excessive privileges
- Unnecessary packages

**Status: Pending Task 4**

---

# 6. Infrastructure-as-Code Analysis

**Scan type:** IaC security scan

IaC scanning was deferred because the starter repository did not contain Terraform or Helm configuration.

Task 4 will introduce infrastructure configuration.

The resulting configuration should be reviewed for:

- Excessive network exposure
- Insecure ingress
- Excessive IAM permissions
- Missing encryption
- Insecure Kubernetes security contexts
- Missing resource limits
- Improper secret handling

**Status: Pending Task 4**

---

# 7. Task 1 Security Hardening

## Share URL Generation

**Classification:** Security hardening  
**Severity:** Low / hardening improvement  
**Origin:** Task 1 implementation

The share-link implementation was hardened to generate the assignment-approved fixed URL:

```text
http://localhost:8000/share/{token}
```

instead of directly deriving the URL from the incoming request host.

This avoids relying on request-derived host information when generating a link.

This is documented as a hardening measure rather than as a critical/high vulnerability in the starter repository.

**Status: Remediated**

---

# 8. Overall Risk Priorities

| Priority | Finding | Status |
|---|---|---|
| P1 | SQL Injection | Remediated |
| P1 | BOLA / IDOR | Remediated |
| P1 | Passwords in logs | Remediated |
| P1 | JWT `none` algorithm | Remediated |
| P1 | Hardcoded JWT secret | Pending |
| P1 | Hardcoded database password | Pending |
| P1 | `python-jose` vulnerabilities | Pending |
| P1 | High-risk Python dependencies | Pending |
| P1 | High-risk Node.js dependencies | Pending |
| P2 | Remaining dependency findings | Pending |
| P2 | Container security | Task 4 |
| P2 | IaC security | Task 4 |

---

# 9. Validation

Following the Task 3 code changes:

- Python syntax validation completed successfully.
- Existing automated API test suite completed successfully.
- **10 tests passed.**
- No test failures were observed.

The remediation changes were therefore validated against the existing application test suite without introducing test failures.