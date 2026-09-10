# Remediation Plan

## Purpose

This document records security findings identified during the security analysis that were not remediated as part of Task 3.

The highest-risk application findings identified in the starter repository were remediated directly in code.

---

## 1. Hardcoded JWT Secret

**Severity:** High

**Finding:**  
The JWT signing secret is hardcoded in `app/config.py`.

**Residual risk:**  
If the source code or deployed application package is exposed, an attacker could obtain the JWT signing secret and potentially create forged authentication tokens. This could result in unauthorized access to protected API endpoints.

**Remediation effort:** Medium

**Recommended remediation:**  
Move the JWT signing secret to a secrets manager or protected runtime environment variable. Rotate the existing secret because it has been stored in source code.

**Compensating controls:**
- Restrict repository access.
- Protect CI/CD secrets.
- Use short-lived access tokens.
- Monitor authentication failures.
- Rotate the exposed secret after migration.

---

## 2. Hardcoded Database Password

**Severity:** High

**Finding:**  
A database password is hardcoded in `app/config.py`.

**Residual risk:**  
Anyone obtaining the source code could obtain the database credential. If the credential is valid against a reachable database, this could allow unauthorized database access.

**Remediation effort:** Medium

**Recommended remediation:**  
Move database credentials to a secrets manager and inject them at runtime. Rotate the exposed credential.

**Compensating controls:**
- Restrict database network access.
- Use least-privilege database permissions.
- Restrict repository access.
- Rotate credentials.
- Monitor database authentication failures.

---

## 3. Python Dependency Vulnerabilities

**Severity:** High overall dependency risk

**Finding:**  
Dependency analysis identified known vulnerabilities in several pinned Python packages, including `python-jose`, `cryptography`, `starlette`, `python-multipart`, and `fastapi`.

**Residual risk:**  
Known vulnerabilities in third-party packages may expose the application to denial of service, authentication-related attacks, request-processing issues, or other security weaknesses depending on the affected functionality.

Exploitability varies by package and application functionality. For example, some `python-multipart` findings affect multipart/form processing, while the application primarily uses JSON request bodies.

**Remediation effort:** Medium to High

**Recommended remediation:**  
Review each vulnerable package and upgrade to a supported secure version after compatibility testing. The JWT dependency should receive particular attention because `python-jose` is directly involved in authentication.

**Compensating controls:**
- Run dependency scanning in CI/CD.
- Keep dependencies pinned and periodically reviewed.
- Monitor application errors and abnormal requests.
- Restrict unnecessary application functionality until vulnerable dependencies are upgraded.
- Perform regression testing after dependency upgrades.

---

## 4. Node.js Dependency Vulnerabilities

**Severity:** High overall dependency risk

**Finding:**  
Dependency analysis identified vulnerabilities involving direct dependencies including `axios`, `express`, and `uuid`, along with vulnerable transitive dependencies in the Express dependency chain.

**Residual risk:**  
Known vulnerabilities in Node.js dependencies could expose the notification service to denial of service, request-handling attacks, SSRF-related issues, redirect issues, or other weaknesses depending on the affected code paths.

**Remediation effort:** Medium

**Recommended remediation:**  
Upgrade affected direct and transitive dependencies to supported secure versions and run the notification-service tests after the upgrades.

**Compensating controls:**
- Restrict access to the notification service.
- Validate and constrain outbound requests.
- Monitor service errors and unusual network activity.
- Run dependency scanning as part of CI/CD.
- Keep production dependencies separate from development dependencies where practical.

---

## 5. Container Image Security

**Severity:** Pending assessment

**Finding:**  
A final container-image assessment was deferred because the starter repository did not contain the production Dockerfile required for Task 4.

**Residual risk:**  
The final application image may contain vulnerable operating-system packages, libraries, excessive privileges, unnecessary utilities, or insecure configuration.

**Remediation effort:** Medium

**Recommended remediation:**  
Complete the production Dockerfile in Task 4, build the application image, scan the resulting image, and remediate applicable high/critical findings.

**Compensating controls:**
- Use a minimal supported base image.
- Run the application as a non-root user.
- Do not embed secrets in the image.
- Pin the base image version/digest where practical.
- Add a container health check.
- Restrict unnecessary container capabilities.

---

## 6. Infrastructure-as-Code Security

**Severity:** Pending assessment

**Finding:**  
IaC scanning was deferred until Task 4 because the starter repository did not contain Terraform or Helm configuration.

**Residual risk:**  
Infrastructure configuration could introduce security weaknesses such as unrestricted network access, excessive IAM permissions, missing encryption, missing resource limits, or insecure workload configuration.

**Remediation effort:** Medium

**Recommended remediation:**  
Run IaC security analysis after Terraform or Helm configuration is added in Task 4.

The review should cover:
- Network exposure
- IAM permissions
- Secrets handling
- Encryption
- Kubernetes security contexts
- Resource limits
- Ingress restrictions

**Compensating controls:**
- Restrict ingress to required sources.
- Apply least-privilege IAM.
- Keep secrets outside source code and manifests.
- Use Kubernetes security contexts.
- Define CPU and memory limits.
- Review infrastructure changes before deployment.

---

## 7. Task 1 Share-Link Security Hardening

**Classification:** Security hardening

**Finding:**  
The share URL was changed to use the assignment-approved fixed URL `http://localhost:8000` instead of directly using the request-derived host.

**Residual risk:**  
The fixed URL is appropriate for the assignment's local deployment but would need to be replaced with the application's trusted public URL for a production deployment.

**Remediation effort:** Low

**Recommended remediation:**  
For production deployment, configure an explicitly trusted application URL rather than relying on an arbitrary request `Host` value.

**Compensating controls:**
- Use a configured trusted application URL.
- Configure trusted hosts at the application/deployment layer.
- Place the application behind a controlled reverse proxy or load balancer.

---

# Remediation Priority

| Priority | Finding | Action |
|---|---|---|
| P1 | Hardcoded JWT secret | Move to secrets manager and rotate |
| P1 | Hardcoded database password | Move to secrets manager and rotate |
| P1 | `python-jose` vulnerabilities | Upgrade and test authentication |
| P1 | Other high-risk Python dependencies | Upgrade and regression test |
| P1 | Node.js high-severity dependencies | Upgrade and regression test |
| P2 | Remaining dependency findings | Address during dependency maintenance |
| P2 | Container findings | Scan and remediate after Task 4 |
| P2 | IaC findings | Scan and remediate after Task 4 |

# Task 3 Completed Fixes

The following security issues were directly remediated in application code:

1. SQL Injection
2. Broken Object-Level Authorization (BOLA/IDOR)
3. Passwords written to application logs
4. JWT `none` algorithm acceptance

In addition, Task 1 share-link URL generation was hardened to use the assignment-approved fixed local URL rather than request-derived host information.

All existing automated API tests pass after the remediation changes.