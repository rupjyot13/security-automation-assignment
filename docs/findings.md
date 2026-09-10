# Security Findings

## 1. Scope

The security analysis covered the VulnTracker application and its deployment artifacts.

The following areas were assessed:

* Application source code — SAST/manual security review
* Python dependencies — SCA
* Node.js dependencies — SCA
* Container image — Docker Scout
* Kubernetes/Helm manifests — Checkov

The findings below are prioritized based on security impact to the VulnTracker application rather than simply reproducing raw scanner output.

---

# 2. Application Security Findings

## F-001 — SQL Injection

**Severity:** High

**Detection:** SAST/manual code review

**Source:** Starter application

**Location:** `app/database.py`

### Description

The scan-search functionality originally constructed SQL using direct string interpolation of the user-supplied search query.

An attacker could manipulate the search input to alter the SQL statement executed against the database.

### Business Impact

VulnTracker stores scan results and vulnerability information. Successful SQL injection could allow an attacker to access or manipulate scan-result data outside the intended application behavior.

Depending on the database configuration and privileges, this could affect confidentiality and integrity of vulnerability information.

### Status

**Remediated in Task 3.**

The search implementation now uses parameterized SQLAlchemy query parameters instead of directly interpolating user input into SQL.

---

## F-002 — Broken Object-Level Authorization (BOLA / IDOR)

**Severity:** High

**Detection:** Manual security review

**Source:** Starter application

**Location:** `app/main.py`

### Description

The original scan access functionality did not consistently enforce ownership when retrieving scan information.

The original `GET /scans/{scan_id}` endpoint looked up a scan using only the supplied scan ID and did not verify that the authenticated user owned the requested scan.

The scan-search functionality also needed to ensure that search results were restricted to scans owned by the authenticated user.

### Business Impact

An authenticated user could potentially manipulate a scan ID and retrieve another user's scan results.

Unauthorized access to another user's search results could expose vulnerability findings, CVE information, descriptions, ownership information, and other scan-related data.

### Remediation

Scan access now requires authentication and ownership validation.

Direct scan retrieval verifies that the requested scan belongs to the authenticated user.

Search results are also restricted using the authenticated user's `owner_id`, so a user cannot search across another user's scans.

### Status

**Remediated in Task 3.**

The implementation enforces ownership for both direct scan retrieval and scan-search results.

---

## F-003 — Passwords Written to Application Logs

**Severity:** High

**Detection:** Manual security review

**Source:** Starter application

**Location:** `app/main.py`

### Description

The original login implementation included the supplied password in login-attempt and failed-login log messages.

### Business Impact

Passwords written to application logs could become accessible through log files, centralized logging systems, monitoring platforms, backups, or users with log access.

This creates a credential disclosure risk.

### Status

**Remediated in Task 3.**

Password values are no longer written to application logs.

---

## F-004 — JWT `none` Algorithm Accepted

**Severity:** High

**Detection:** Manual security review

**Source:** Starter application

**Location:** `app/auth.py`

### Description

The original JWT validation explicitly allowed both the configured signing algorithm and the `none` algorithm.

The `none` algorithm represents an unsigned token and should not be accepted when the application requires signed JWTs.

### Business Impact

An attacker able to submit an unsigned or incorrectly signed token could potentially bypass authentication controls and gain unauthorized access to protected VulnTracker functionality.

### Status

**Remediated in Task 3.**

JWT decoding now permits only the configured `HS256` signing algorithm.

---

## F-005 — Hardcoded JWT Secret

**Severity:** High

**Detection:** SAST/manual security review

**Source:** Starter application

**Location:** `app/config.py`

### Description

The starter application contained a hardcoded JWT signing secret in source code.

### Business Impact

Anyone gaining access to the source repository could obtain the signing secret and potentially create valid authentication tokens.

This could compromise authentication across the application.

### Status

**Remediated as part of Task 4 configuration hardening.**

The application now obtains `SECRET_KEY` from environment-based configuration, with a random local-development fallback when it is not supplied.

Production deployment obtains the secret through the configured external secret-management flow.

---

## F-006 — Hardcoded Database Password

**Severity:** High

**Detection:** SAST/manual security review

**Source:** Starter application

**Location:** `app/config.py`

### Description

The starter configuration contained a database password directly in application source code.

### Business Impact

Source-code access could expose database credentials.

Compromised database credentials could potentially allow unauthorized access to application data.

### Status

**Remediated as part of Task 4 configuration hardening.**

`DB_PASSWORD` is now supplied through environment-based configuration and the Helm deployment obtains it through the configured external secret-management flow.

---

# 3. Task 1 Security Hardening

## F-007 — Shared Report Link Security Hardening

**Severity:** Security hardening

**Detection:** Security review during Task 1 implementation

**Source:** Task 1 implementation

**Location:** Shared report-link functionality

### Description

Task 1 introduced functionality allowing an authenticated scan owner to create a shareable report link.

Because the link provides access to scan information without requiring the recipient to authenticate normally, the implementation was hardened to reduce the risk of token disclosure, unauthorized access, and indefinite link validity.

This is documented as **security hardening introduced during Task 1**, rather than as a critical/high vulnerability that originally existed in the starter application.

### Security Controls Implemented

The shared report-link implementation includes:

* Cryptographically secure random share tokens
* SHA-256 hashing of the share token before database storage
* Expiration of share links after 24 hours
* Optional password protection for shared reports
* Password hashing rather than plaintext password storage
* Validation of token expiration
* Generic not-found behavior for invalid or expired links
* Authentication and ownership checks when creating a share link

### Business Impact

Without appropriate controls, a leaked or indefinitely valid share token could provide unauthorized access to vulnerability information.

The implemented controls reduce the likelihood and impact of unauthorized access through shared report links.

### Status

**Implemented as Task 1 security hardening.**

The shared-link feature was implemented with security controls appropriate to the assignment scope.

Detailed regression testing of all shared-link scenarios was not included in the final test suite.

---

# 4. Software Composition Analysis Findings

## F-008 — Vulnerable Python Dependencies

**Severity:** High / Medium depending on dependency and exercised functionality

**Detection:** Python SCA using `pip-audit`

**Source:** Starter dependency set

### Description

The dependency scan identified vulnerabilities in several pinned Python dependencies.

Important affected areas included:

* `python-jose`
* `cryptography`
* `fastapi` / Starlette-related dependencies
* `python-multipart`
* Other transitive dependencies

The `python-jose` findings are particularly relevant because VulnTracker uses JWT authentication.

### Business Impact

Vulnerable dependencies may expose the application to denial-of-service, authentication-related attacks, cryptographic weaknesses, or other security issues depending on the affected code path and deployment configuration.

### Status

**Follow-up required.**

Dependency upgrades were not performed as part of the current remediation scope because they require compatibility testing, regression validation, application testing, and another security scan.

The findings were therefore not silently treated as resolved.

---

## F-009 — Vulnerable Node.js Dependencies

**Severity:** High / Medium / Low depending on package

**Detection:** Node.js dependency audit / lock-file analysis

**Source:** Starter dependency set

### Description

The Node.js notification service dependency set contains vulnerabilities involving direct and transitive dependencies.

The primary affected areas identified were:

* `axios`
* `express`
* `uuid`
* Express-related transitive dependencies such as `body-parser`, `path-to-regexp`, `qs`, `cookie`, `send`, and `serve-static`

### Business Impact

Depending on how the notification service uses the affected functionality, vulnerabilities may create risks such as request manipulation, server-side request abuse, denial of service, or other application compromise.

### Status

**Follow-up required.**

Dependency upgrades were not silently treated as resolved.

Controlled package upgrades, compatibility testing, regression testing, and another dependency/container scan should be performed as a follow-up activity.

---

# 5. Container Image Findings

## F-010 — Vulnerabilities in Container Base Image and Installed Packages

**Severity:** Critical / High / Medium / Low depending on CVE

**Detection:** Docker Scout

**Source:** Task 4 container image

### Description

Docker Scout identified vulnerabilities in operating-system and Python packages included in the `vulntracker-app:task4` container image.

The scan contained **193 failed vulnerability results**, including:

* 6 Critical
* 69 High
* 60 Medium
* 53 Low
* 5 Unspecified

The findings include vulnerabilities in packages such as glibc, OpenSSL, Perl, GnuTLS, util-linux, and Python packages.

### High-Priority Example

Docker Scout identifies `CVE-2026-4437` affecting the image's Debian `glibc` package.

The reported installed version is `2.36-9+deb12u10`, with a fixed version of `2.36-9+deb12u14`.

The reported issue involves processing crafted DNS responses through affected glibc functionality.

The report also contains other high-severity package findings, including vulnerabilities affecting packages such as Perl, OpenSSL, dpkg, cryptography, GnuTLS, and others.

### Important Context

The raw Scout report also contains older, disputed, or distribution-classified findings where the underlying issue may be unimportant or not applicable to the application's actual execution path.

For example, several findings explicitly contain Debian/upstream classifications such as "unimportant", "disputed", or negligible impact.

Therefore, the 193 results should not be interpreted as 193 equally exploitable application vulnerabilities.

### Business Impact

A vulnerable container base image increases the attack surface of the deployed application.

Exploitation of a relevant OS or library vulnerability could result in denial of service, information disclosure, privilege escalation, or compromise of the application container depending on exploitability and runtime exposure.

### Security Hardening Already Applied

The container and Kubernetes deployment were hardened using:

* Minimal Python 3.11 slim base image
* Pinned Python base-image version
* Non-root execution
* Read-only root filesystem at Kubernetes runtime
* Dropped Linux capabilities
* Disabled privilege escalation
* RuntimeDefault seccomp profile
* Resource limits
* Image digest pinning in Helm

These controls reduce runtime exposure but do not remove vulnerabilities contained in the image packages themselves.

### Status

**Follow-up required / Not remediated in the current assignment scope.**

Remaining image CVEs should be addressed through controlled base-image and package updates followed by regression testing and another container scan.

---

# 6. Infrastructure-as-Code Findings

## F-011 — Kubernetes Secret Supplied Through Environment Variables

**Severity:** Medium / configuration hardening

**Detection:** Checkov

**Check:** `CKV_K8S_35`

**Source:** Task 4 Helm deployment

### Description

The Helm deployment retrieves secrets from the external secret-management flow and supplies the resulting Kubernetes Secret values to the application through environment variables.

Checkov recommends mounting secrets as files instead.

### Business Impact

Environment variables can potentially be exposed through process or environment inspection and debugging mechanisms available to sufficiently privileged users or processes.

### Current Secret Flow

```text
AWS Secrets Manager
        |
        v
External Secrets Operator
        |
        v
Kubernetes Secret
        |
        v
Application environment variables
```

The secret values are not committed to source control or embedded in the Docker image.

### Compensating Controls

The current deployment also uses several controls that reduce the overall exposure:

* Secrets originate from AWS Secrets Manager
* External Secrets Operator manages synchronization
* Secret values are not stored in source control
* Secret values are not embedded in the container image
* Application containers run as non-root
* Linux capabilities are dropped
* Privilege escalation is disabled
* Root filesystem is read-only
* RuntimeDefault seccomp profile is enabled
* Automatic service-account-token mounting is disabled

### Status

**Accepted for the current assignment scope.**

The Checkov scan completed with **93 passed checks and 1 failed check**, with `CKV_K8S_35` being the remaining finding.

The residual risk and future remediation are documented separately in `docs/remediation-plan.md`.

---

# 7. Additional Application Security Findings

## F-012 — Global Exception Handler Leaks Sensitive Internal Information

**Severity:** Medium — Information Disclosure

**Detection:** Manual security review

**Source:** Application source code

**Location:** Global exception handler in `app/main.py`

### Description

The application's global exception handler currently returns detailed internal exception information in HTTP 500 responses.

The response can expose information such as:

* Internal error message
* Exception type
* Python traceback
* Request path

### Business Impact

Detailed exception information can provide attackers with implementation details that may assist reconnaissance and exploitation.

Tracebacks may reveal application structure, source-code locations, library versions, database operations, file paths, or other internal information.

### Recommended Remediation

Production responses should return a generic error message such as:

```json
{
  "detail": "Internal server error"
}
```

Detailed exception information should instead be recorded in protected server-side logs with appropriate access controls.

### Status

**Not remediated in the current assignment scope.**

The finding is documented for future remediation.

---

## F-013 — Overly Permissive CORS Configuration

**Severity:** Medium — Configuration Hardening

**Detection:** Manual security review

**Source:** Application configuration

### Description

The current CORS configuration dynamically reflects the request `Origin` and permits credentials.

The configuration also allows broad request headers.

This is more permissive than an explicit environment-specific origin allowlist.

### Business Impact

Permissive CORS configuration can increase the risk of unauthorized browser-based cross-origin access to authenticated application endpoints.

When credentials are permitted, an overly broad origin policy can increase the impact of browser-based attacks against authenticated users.

### Recommended Remediation

Production deployments should use an explicit allowlist of trusted frontend origins.

For example:

```text
ALLOWED_ORIGINS=http://localhost:3000,http://localhost:5173
```

The allowed origins should be environment-specific and should not simply reflect arbitrary request origins.

CORS configuration should be treated as a defense-in-depth control and should not replace authentication and authorization checks.

### Status

**Not remediated in the current assignment scope.**

The finding is documented for future configuration hardening.

---

## F-014 — Hardcoded Notification Service Key

**Severity:** Medium — Secret Management

**Detection:** Manual security review

**Source:** Node.js notification service

### Description

The notification service contains a hardcoded credential-like value:

```text
SERVICE_KEY: 'notify-svc-k3y-d3adb33f-pr0'
```

The value appears to be defined in the service configuration.

The current `/notify` endpoint does not enforce this value as an authentication or authorization credential, so its current runtime security impact is limited by its apparent unused status.

### Business Impact

If the value represents an actual service credential and is later used for authentication, authorization, or communication with another service, storing it directly in source code could expose the credential to anyone with repository access.

Hardcoded credentials also make credential rotation more difficult.

### Recommended Remediation

If the value is required:

* Remove it from source code
* Supply it through environment-based configuration or a secret-management system
* Rotate the credential if it has ever been used as a real secret
* Enforce authentication/authorization where the service key is intended to protect an endpoint

If the value is only test/demo data, it should still be replaced with clearly non-secret placeholder data.

### Status

**Not remediated / Out of current assignment scope.**

No changes were made to the notification service because the assignment scope did not require modification of its notification behavior.

---

# 8. IaC Security Controls Implemented

The Helm deployment includes several security controls intended to reduce the application's infrastructure attack surface:

* Dedicated `vulntracker` namespace
* Non-root container execution
* Explicit UID/GID
* Read-only root filesystem
* Disabled privilege escalation
* Dropped Linux capabilities
* RuntimeDefault seccomp profile
* Disabled automatic service-account-token mounting
* CPU and memory requests/limits
* Image digest pinning
* Internal ALB configuration
* Restricted ingress CIDR
* NetworkPolicy
* External secret management
* Kubernetes readiness and liveness probes

These controls complement the application-level remediations but do not eliminate the outstanding dependency, container-image, or accepted Kubernetes secret-environment-variable findings.

---

# 9. Findings Summary

| ID    | Finding                                 | Severity                 | Source                    | Status                        |
| ----- | --------------------------------------- | ------------------------ | ------------------------- | ----------------------------- |
| F-001 | SQL Injection                           | High                     | Starter application       | Remediated                    |
| F-002 | BOLA / IDOR                             | High                     | Starter application       | Remediated                    |
| F-003 | Passwords in Logs                       | High                     | Starter application       | Remediated                    |
| F-004 | JWT `none` Algorithm                    | High                     | Starter application       | Remediated                    |
| F-005 | Hardcoded JWT Secret                    | High                     | Starter application       | Remediated                    |
| F-006 | Hardcoded DB Password                   | High                     | Starter application       | Remediated                    |
| F-007 | Shared Report Link Security Hardening   | Security hardening       | Task 1 implementation     | Implemented                   |
| F-008 | Vulnerable Python Dependencies          | High/Medium              | Starter dependencies      | Follow-up                     |
| F-009 | Vulnerable Node.js Dependencies         | High/Medium/Low          | Starter dependencies      | Follow-up                     |
| F-010 | Container Image Vulnerabilities         | Critical/High/Medium/Low | Task 4 image              | Follow-up                     |
| F-011 | Secret as Environment Variable          | Medium / hardening       | Task 4 Helm               | Accepted                      |
| F-012 | Global Exception Information Disclosure | Medium                   | Application               | Not Remediated                |
| F-013 | Overly Permissive CORS                  | Medium                   | Application configuration | Not Remediated                |
| F-014 | Hardcoded Notification Service Key      | Medium                   | Node.js service           | Not Remediated / Out of Scope |

---

# 10. Overall Assessment

The highest-impact application-level vulnerabilities identified in the starter code were remediated.

These include:

* SQL Injection
* Broken Object-Level Authorization / IDOR
* Passwords written to logs
* JWT `none` algorithm acceptance
* Hardcoded JWT secret
* Hardcoded database password

The Task 1 shared-report functionality was also implemented with additional security controls for token generation, token storage, expiration, optional password protection, and access validation.

The deployment was additionally hardened against several common container and Kubernetes security risks, including non-root execution, privilege escalation, Linux capabilities, filesystem access, seccomp configuration, service-account token exposure, resource controls, network restrictions, and external secret management.

The primary remaining risks are:

1. Python dependency vulnerabilities
2. Node.js dependency vulnerabilities
3. Container image vulnerabilities
4. Kubernetes secret delivery through environment variables
5. Detailed exception information exposed through 500 responses
6. Overly permissive CORS configuration
7. Hardcoded notification-service credential-like configuration

The dependency and container findings should be addressed through controlled upgrades, compatibility/regression testing, image rebuilding, and repeated security scanning.

The accepted Kubernetes secret-environment-variable finding and the additional application findings should be addressed as part of future security hardening.

Overall, the current implementation materially improves the security posture of the VulnTracker application while keeping remediation within the defined assignment scope.
