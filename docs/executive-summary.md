# Executive Summary

## 1. Overview

The VulnTracker application and its deployment artifacts were reviewed from an application security, dependency, container, and Kubernetes security perspective.

The assessment covered:

* Application source code through SAST and manual security review
* Python dependencies using software composition analysis
* Node.js dependencies using dependency analysis
* Container image vulnerabilities using Docker Scout
* Kubernetes and Helm security configuration using Checkov
* Security controls implemented as part of the assignment tasks

The objective was to identify significant security weaknesses, remediate selected application vulnerabilities, and document residual risks that require further remediation.

---

## 2. Security Improvements Completed

The highest-impact application vulnerabilities identified in the starter application were remediated.

### SQL Injection

The scan-search functionality was changed from unsafe SQL string interpolation to parameterized SQLAlchemy queries.

This prevents user-controlled search input from being interpreted as SQL syntax.

### Broken Object-Level Authorization / IDOR

Authorization checks were added so authenticated users can access only their own scan data.

This includes:

* Direct scan retrieval
* Scan-search results

Search queries are restricted using the authenticated user's `owner_id`.

### Passwords in Application Logs

Password values were removed from login-related application logging.

This prevents credentials from being unnecessarily exposed through application and centralized logging systems.

### JWT `none` Algorithm

JWT validation was changed so that only the configured `HS256` signing algorithm is accepted.

Unsigned JWTs using the `none` algorithm are no longer accepted.

### Hardcoded Credentials

Hardcoded JWT and database credentials in the starter configuration were removed from application source configuration.

The application now uses environment-based configuration and the configured external secret-management flow for production deployment.

---

## 3. Task 1 Security Hardening

The shared report-link functionality introduced during Task 1 was implemented with additional security controls.

The implementation includes:

* Cryptographically secure share tokens
* SHA-256 hashing of share tokens before database storage
* 24-hour link expiration
* Optional password protection
* Password hashing
* Ownership checks when creating share links
* Generic handling of invalid or expired links

These controls reduce the risk associated with sharing vulnerability reports through externally accessible links.

The shared-link functionality is considered **security hardening introduced during Task 1**, rather than a pre-existing critical/high vulnerability in the starter application.

---

## 4. Infrastructure Security Improvements

The Kubernetes and Helm deployment was hardened using several security controls.

Implemented controls include:

* Dedicated application namespace
* Non-root container execution
* Explicit UID/GID
* Read-only root filesystem
* Disabled privilege escalation
* Dropped Linux capabilities
* RuntimeDefault seccomp profile
* Disabled automatic service-account-token mounting
* CPU and memory requests/limits
* Image digest pinning
* Restricted ingress CIDR
* Internal ALB configuration
* NetworkPolicy
* External secret management
* Readiness and liveness probes

These controls reduce the application's runtime and infrastructure attack surface.

---

## 5. Security Scan Results

### Kubernetes / Helm

The Checkov scan completed with:

* **93 passed checks**
* **1 failed check**

The remaining finding was:

`CKV_K8S_35` — Kubernetes secrets supplied through environment variables.

The current implementation obtains secrets through the external secret-management flow rather than storing them in source code or the container image.

The finding is therefore accepted for the current assignment scope, with future remediation documented separately.

### Container Image

Docker Scout identified **193 failed vulnerability results** in the container image, consisting of:

* 6 Critical
* 69 High
* 60 Medium
* 53 Low
* 5 Unspecified

These results include vulnerabilities in operating-system and Python packages.

The raw scanner count should not be interpreted as 193 equally exploitable application vulnerabilities. Some findings have distribution-specific classifications such as unimportant, disputed, or negligible impact.

The container has nevertheless been hardened and the remaining relevant CVEs require controlled base-image and package updates.

---

## 6. Remaining Security Risks

Several findings remain open and require follow-up remediation.

### Dependency Vulnerabilities

Python dependency scanning identified vulnerabilities involving packages including:

* `python-jose`
* `cryptography`
* `fastapi`
* Starlette-related dependencies
* `python-multipart`
* Other transitive dependencies

Node.js dependency analysis also identified vulnerabilities involving packages including:

* `axios`
* `express`
* `uuid`
* Related transitive dependencies

These dependencies should be upgraded in a controlled manner with compatibility testing, regression testing, and subsequent security scans.

### Container Image Vulnerabilities

The container image still contains reported OS and library vulnerabilities.

Future remediation should include:

1. Updating the base image and affected packages.
2. Rebuilding the image.
3. Running application regression tests.
4. Running Docker Scout again.
5. Reviewing remaining CVEs based on severity and exploitability.

### Kubernetes Secret Environment Variables

Checkov identified the use of Kubernetes Secret values as environment variables.

The current configuration is accepted with compensating controls, but a future implementation could mount sensitive values as files where application compatibility permits.

### Global Exception Information Disclosure

The global exception handler currently exposes detailed internal information in 500 responses, including exception and traceback information.

Future remediation should return a generic error response to clients while retaining detailed diagnostic information in protected server-side logs.

### Overly Permissive CORS

The current CORS configuration is more permissive than an explicit environment-specific origin allowlist.

Future remediation should restrict allowed origins to trusted frontend applications.

### Notification Service Credential-Like Configuration

The Node.js notification service contains a hardcoded credential-like `SERVICE_KEY`.

The value appears unused by the current `/notify` endpoint and was not modified because notification-service changes were outside the current assignment scope.

If the value is intended to be a real credential, it should be removed from source code, rotated if necessary, and managed through an appropriate secret-management mechanism.

---

## 7. Testing and Validation


### Targeted Search Authorization Regression Test

A targeted regression test was added for the `/scans/search` endpoint to validate the BOLA/IDOR remediation. The test creates matching SQL findings for two different authenticated users and verifies that a user's search results contain only that user's own scan, even when another user's scan matches the same search query.

This provides automated validation that the search endpoint enforces the authenticated user's ownership boundary.


### Application tests were executed after the security remediation changes.

The final test execution completed successfully:

```text
10 passed
```

Python compilation checks were also performed successfully for the modified application modules.

The testing confirms that the existing application test suite passes after the remediation changes.

The shared-report-link functionality received security hardening, but comprehensive regression testing of every shared-link scenario was not included in the final test suite.

---

## 8. Overall Security Assessment

The assignment significantly improves the security posture of the VulnTracker application.

The major application-level vulnerabilities selected for remediation were addressed, including:

* SQL Injection
* Broken Object-Level Authorization / IDOR
* Password exposure through logs
* JWT `none` algorithm acceptance
* Hardcoded JWT secret
* Hardcoded database password

The deployment was also strengthened through container and Kubernetes security controls such as non-root execution, restricted Linux capabilities, read-only filesystem configuration, seccomp, NetworkPolicy, resource limits, image digest pinning, and external secret management.

However, the application should **not be considered completely vulnerability-free**.

The remaining dependency, container-image, configuration, and information-disclosure findings require continued remediation and periodic rescanning.

---

## 9. Recommended Next Steps

The recommended security follow-up priorities are:

### Priority 1 — Dependency and Container Updates

* Review critical and high-severity dependency findings.
* Upgrade affected Python and Node.js packages.
* Update the container base image and affected OS packages.
* Rebuild and rescan the container image.
* Perform regression testing after upgrades.

### Priority 2 — Application Security Hardening

* Replace detailed 500 responses with generic error responses.
* Restrict CORS to explicit trusted origins.
* Review and remove or securely manage the notification-service key.

### Priority 3 — Kubernetes Secret Handling

Evaluate migrating application secrets from environment variables to file-based secret mounts where practical and compatible with the application.

### Priority 4 — Continuous Security Scanning

Security scanning should become part of the CI/CD lifecycle.

A recommended pipeline sequence is:

```text
Code Commit
    |
    v
SAST
    |
    v
Dependency / SCA Scan
    |
    v
Secret Scan
    |
    v
IaC Security Scan
    |
    v
Container Build
    |
    v
Container Image Scan
    |
    v
Security Quality Gates
    |
    v
Deployment
```

This allows security issues to be identified before deployment rather than only during periodic reviews.

---

## 10. Conclusion

The VulnTracker security assessment identified multiple application and infrastructure security risks.

The selected high-impact application vulnerabilities were successfully remediated, while additional security controls were introduced for the shared report functionality and Kubernetes deployment.

Outstanding dependency, container, and configuration findings have been documented rather than incorrectly marked as resolved.

The resulting implementation provides a stronger security baseline while clearly identifying the remaining risks and the recommended path for continued remediation.
