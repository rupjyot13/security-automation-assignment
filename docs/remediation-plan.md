# Remediation Plan

## 1. Remediated Findings

### 1.1 SQL Injection

**Severity:** High

**Status:** Remediated

**Source:** Starter application (`app/database.py`)

The scan search functionality originally constructed SQL using string interpolation. User-controlled search input could therefore alter the SQL statement.

**Remediation:**

The search query was changed to use a SQLAlchemy parameterized query with a bound `:search` parameter. User input is no longer directly interpolated into the SQL statement.

**Residual risk:**

The identified SQL injection vulnerability is remediated. Continued use of parameterized database queries is required for future database functionality.

---

### 1.2 Broken Object-Level Authorization (BOLA / IDOR)

**Severity:** High

**Status:** Remediated

**Source:** Starter application (`app/main.py`, `app/database.py`)

The original scan access functionality did not consistently enforce ownership when accessing scan records. In particular, the original `GET /scans/{scan_id}` endpoint retrieved a scan using only its ID and did not verify that the authenticated user owned the requested scan.

The scan search functionality also required an explicit ownership check so that an authenticated user could not search and retrieve another user's scan records.

**Remediation:**

Authorization and ownership checks were applied to scan access operations.

The direct scan retrieval endpoint requires authentication and retrieves a scan only when both the requested scan ID and the authenticated user's `owner_id` match.

The scan search database query was also changed to require the authenticated user's `owner_id`:

```python
WHERE owner_id = :owner_id
  AND (
      title LIKE :search
      OR description LIKE :search
      OR cve_id LIKE :search
  )
```

The `/scans/search` endpoint passes the authenticated user's ID to the database search function.

If a scan does not belong to the authenticated user, it is not returned.

**Validation:**

The existing automated test suite passes after the ownership enforcement changes:

```text
10 passed
```

**Residual risk:**

The identified BOLA/IDOR issue is remediated for the affected scan access and search operations. Future endpoints exposing object identifiers must apply the same ownership or authorization checks.

---

### 1.3 Passwords Written to Application Logs

**Severity:** High

**Status:** Remediated

**Source:** Starter application (`app/main.py`)

The original login implementation wrote the supplied password to application logs during login attempts. This could expose user credentials through log files, log aggregation systems, or monitoring platforms.

**Remediation:**

Password values were removed from both successful login-attempt and failed-login log messages. Logging now records the username and login event without recording the password.

**Residual risk:**

The identified password logging issue is remediated. Production logging should continue to avoid credentials, tokens, session identifiers, and other sensitive authentication material.

---

### 1.4 JWT `none` Algorithm Acceptance

**Severity:** High

**Status:** Remediated

**Source:** Starter application (`app/auth.py`)

The original JWT validation configuration explicitly allowed both the configured `HS256` algorithm and the `none` algorithm. Accepting an unsigned JWT algorithm can allow token integrity protections to be bypassed if an attacker can submit a token using the unsupported algorithm.

**Remediation:**

JWT decoding was restricted to the configured `HS256` algorithm:

```python
jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
```

The `none` algorithm is no longer accepted.

**Residual risk:**

The identified `none` algorithm acceptance issue is remediated. JWT secret management and algorithm configuration must remain controlled in production.

---

## 2. Task 1 Security Hardening

### Shared Report Link Protection

**Status:** Implemented

The Task 1 shared-report functionality was implemented with the following controls:

* Only an authenticated owner can create a share link.
* Share tokens are generated using cryptographically secure random values.
* Only the SHA-256 hash of the share token is stored in the database.
* Share links expire after 24 hours.
* Optional share-link passwords are stored as password hashes rather than plaintext.
* Expired or invalid links return a generic not-found response.
* The share URL uses the assignment-approved localhost URL.

These controls reduce the risk associated with unauthorized access to shared scan reports.

**Note:** The original Task 1 implementation was not classified as a critical/high starter vulnerability. These controls are security hardening applied while implementing the requested feature.

---

## 3. Findings Not Remediated

### 3.1 Kubernetes Secrets Supplied as Environment Variables

**Severity:** Medium / configuration hardening

**Status:** Accepted for current scope

**Finding:** Checkov `CKV_K8S_35`

The Helm deployment retrieves application secrets through the following intended flow:

```text
AWS Secrets Manager
        ↓
External Secrets Operator
        ↓
Kubernetes Secret
        ↓
Application environment variables
```

The Checkov scan reports that Kubernetes secrets are supplied to the container through environment variables instead of being mounted as secret files.

### Residual Risk

Environment variables can potentially be exposed through process/environment inspection or debugging mechanisms available to sufficiently privileged users or processes.

The secret values are nevertheless not stored in the Git repository or Docker image.

### Remediation Effort

Changing this implementation to file-based secret injection would require:

1. Mounting the Kubernetes Secret as a volume.
2. Updating the application configuration to read the secret values from files.
3. Updating deployment and application tests.
4. Revalidating application startup and authentication behavior.

This is additional application and deployment work beyond the required assignment scope.

### Compensating Controls

The current implementation provides the following controls:

* Secrets originate from AWS Secrets Manager.
* Secrets are synchronized using External Secrets Operator.
* Secret values are not committed to source control.
* Secret values are not embedded in the Docker image.
* The container runs as a non-root user.
* Linux capabilities are dropped.
* Privilege escalation is disabled.
* The root filesystem is read-only.
* A RuntimeDefault seccomp profile is configured.
* Kubernetes service-account token automounting is disabled.

### Future Remediation

For a production implementation with stricter secret-handling requirements, secrets should be mounted as files and the application should read them from the mounted secret paths instead of environment variables.

---

### 3.2 Global Exception Handler Leaks Sensitive Internal Information

**Severity:** Medium / Information Disclosure

**Status:** Not Remediated

**Finding:** The global exception handler currently returns detailed exception information directly to API clients.

The response includes values such as:

```python
{
    "error": str(exc),
    "type": type(exc).__name__,
    "traceback": traceback.format_exc(),
    "path": str(request.url),
}
```

An unexpected application exception could therefore expose sensitive internal information to a remote client.

### Potential Impact

Information exposed through the response may include:

* Python stack traces
* Internal file paths
* Exception details
* Database or SQL-related error information
* Request URLs
* Application implementation details

This information could assist an attacker in understanding the application's internal structure and identifying additional attack paths.

### Residual Risk

Detailed internal exception information remains exposed to clients when an unexpected server-side exception occurs.

This creates an information-disclosure risk and should be addressed before production deployment.

### Recommended Remediation

The API should return a generic error response to the client, for example:

```json
{
  "detail": "Internal server error"
}
```

Detailed exception information should instead be recorded only in server-side application logs with appropriate access controls.

### Remediation Effort

Low.

The change can be implemented in the global exception handler without requiring a significant application architecture change.

### Compensating Controls

No application-level remediation was implemented for this finding in the current assignment scope.

Server and log access should remain restricted, and production monitoring should capture unexpected exceptions without exposing their details to API consumers.

### Future Remediation

Replace the detailed client-facing exception response with a generic HTTP 500 response and retain the full diagnostic information only in controlled server-side logs.

---

### 3.3 Overly Permissive CORS Configuration

**Severity:** Medium / Configuration Hardening

**Status:** Not Remediated

**Finding:**

The current CORS handling dynamically reflects the request's `Origin` and enables credentials:

```text
Access-Control-Allow-Origin: <request origin>
Access-Control-Allow-Credentials: true
```

The implementation also permits broadly defined request headers.

This effectively trusts browser origins supplied by clients rather than maintaining an explicit allowlist of trusted application origins.

### Residual Risk

Overly permissive cross-origin configuration can allow requests from unintended browser origins.

When credentials are enabled, incorrect CORS configuration can increase the impact of cross-origin attacks against authenticated browser sessions.

Authentication and authorization controls remain necessary, but they do not replace proper CORS configuration.

### Remediation Effort

Low.

A production implementation should define explicitly trusted origins through configuration or environment variables and allow only those origins.

For example:

```text
ALLOWED_ORIGINS=http://localhost:3000,http://localhost:5173
```

The application should reject or omit CORS authorization for origins not present in the configured allowlist.

### Compensating Controls

The application continues to require authentication for protected API operations.

However, authentication alone is not considered a replacement for an appropriately restricted CORS policy.

### Future Remediation

Implement environment-based CORS configuration with an explicit allowlist of trusted browser origins. Credentials should only be enabled when required by the application.

---

### 3.4 Hardcoded Secret in Notification Service

**Severity:** Medium / Secret Management

**Status:** Not Remediated / Out of Current Scope

**Finding:**

The Node.js notification service contains a credential-like value directly in source code:

```text
SERVICE_KEY: 'notify-svc-k3y-d3adb33f-pr0'
```

A credential or secret committed to source control can potentially be exposed to anyone with access to the repository.

The current prototype does not appear to use this value for authentication, and the `/notify` endpoint does not currently enforce the key.

### Residual Risk

The hardcoded value represents poor secret-management practice and could become a security issue if the value is subsequently used as an active credential.

If the value is intended to be a real credential, anyone with access to the source repository may be able to obtain it.

### Remediation Effort

Low to Medium.

The appropriate remediation depends on the intended design:

1. Remove the value completely if it is unused, or
2. Move it to environment/secret management and enforce authentication using the configured secret.

If the value has ever been used as a real credential, it should also be rotated.

### Compensating Controls

The current application does not appear to rely on this value for authentication of the notification endpoint.

No changes were made to the notification service because the assignment does not require modifications to this component.

### Scope Decision

This finding is documented but intentionally not remediated as part of the current assignment scope.

Modifying the notification service would expand the implementation beyond the required application security remediation work.

### Future Remediation

Remove unused credential-like configuration or migrate required secrets to an appropriate secret-management mechanism and enforce authentication at the notification-service endpoint.

---

## 4. Dependency Findings

Dependency scanning identified vulnerabilities in several pinned dependencies. These were recorded as part of the security analysis and are not silently treated as resolved.

The highest-priority dependency areas include:

* `python-jose`
* `cryptography`
* `fastapi` / related Starlette and multipart dependencies
* Node.js `axios`
* Node.js `express`
* Node.js `uuid`

Dependency upgrades require compatibility testing because they can introduce breaking changes or alter application behavior.

**Recommended follow-up:** establish supported dependency versions, upgrade vulnerable production dependencies, rerun SCA, execute the complete test suite, rebuild the container image, and rerun container scanning.

---

## 5. Remediation Summary

| Finding                                         | Severity                            | Status                              |
| ----------------------------------------------- | ----------------------------------- | ----------------------------------- |
| SQL Injection                                   | High                                | Remediated                          |
| BOLA / IDOR                                     | High                                | Remediated                          |
| Passwords in Logs                               | High                                | Remediated                          |
| JWT `none` Algorithm                            | High                                | Remediated                          |
| Task 1 Shared Link Security                     | Security hardening                  | Implemented                         |
| Kubernetes Secret as Environment Variable       | Medium / hardening                  | Accepted with compensating controls |
| Global Exception Handler Information Disclosure | Medium                              | Not Remediated                      |
| Overly Permissive CORS                          | Medium / hardening                  | Not Remediated                      |
| Hardcoded Notification-Service Secret           | Medium / secret management          | Not Remediated / Out of Scope       |
| Vulnerable Dependencies                         | High/Medium depending on dependency | Follow-up required                  |

The remediation approach prioritizes direct application security vulnerabilities first, while documenting remaining dependency, infrastructure, configuration, and information-disclosure risks rather than claiming them as resolved without validation.

The additional findings documented in this section are intentionally left unchanged in the application because they are outside the currently selected remediation scope.
