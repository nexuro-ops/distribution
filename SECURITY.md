# Security Policy

This document outlines the security practices and procedures for the SIGHUP Distribution project.

## Supported Versions

SIGHUP Distribution follows a **3-minor-version support window** aligned with Kubernetes releases.

| Version | Kubernetes Target | Status | Support Window | EOL Date |
|---------|------------------|--------|---|---|
| 1.35.x  | 1.35+ | ✅ Current (Stable) | Full support | ~September 2026 |
| 1.34.x  | 1.34+ | ✅ Maintenance | Extended support | ~June 2026 |
| 1.33.x  | 1.33+ | ⚠️ Legacy | Critical patches only | ~March 2026 |
| < 1.33  | - | ❌ Unsupported | No updates | - |

**Security Patches:** Monthly for current version, as-needed for maintenance versions, critical only for legacy versions.

---

## Reporting Security Vulnerabilities

**🔒 IMPORTANT: Do NOT open a public GitHub issue for security vulnerabilities.**

If you discover a security vulnerability in SIGHUP Distribution, please report it responsibly to:

**Email:** security@sighup.io
**Subject:** Security Vulnerability Report - SIGHUP Distribution

Please include:
1. **Vulnerability Description** - Clear explanation of the issue
2. **Affected Versions** - Which versions are impacted
3. **Reproduction Steps** - How to reproduce (if applicable)
4. **Potential Impact** - Severity and consequences
5. **Suggested Fix** - Any proposed remediation (if available)
6. **Your Contact Info** - For follow-up communications

**Response Timeline:**
- **Initial Response:** Within 48 hours
- **Vulnerability Confirmation:** Within 5 business days
- **Fix Release:** Within 7-14 days (depending on severity)
- **Public Disclosure:** Coordinated after fix is released

---

## Security Practices

### Dependency Management
- ✅ Automated dependency scanning via GitHub Dependabot
- ✅ Weekly updates for security patches
- ✅ Immediate patching for critical vulnerabilities
- ✅ Manual security audits of third-party libraries

### Code Review
- ✅ Security-focused peer review process
- ✅ Static analysis tools (go vet, golangci-lint)
- ✅ Automated security scanning in CI/CD
- ✅ Manual security code review for critical changes

### Testing & Validation
- ✅ Comprehensive unit test coverage
- ✅ Integration testing on staging environments
- ✅ End-to-end testing on Talos Linux clusters
- ✅ Performance baseline validation

### Compliance & Standards
- ✅ CIS Kubernetes Benchmark compliance
- ✅ NIST Cybersecurity Framework alignment
- ✅ OWASP Top 10 risk mitigation
- ✅ Kubernetes security best practices

### Release Security
- ✅ Security audit before each release
- ✅ Signed git tags (GPG)
- ✅ SBOM (Software Bill of Materials) generation
- ✅ Changelog with security notes
- ✅ Penetration testing for major releases

---

## Security in v1.35.0

The v1.35.0 release includes several critical security improvements:

### Breaking Security Changes
1. **Mandatory Cgroup v2** - Enforced resource isolation
2. **RBAC Updates** - pod/exec requires `create` verb (privilege escalation prevention)
3. **Image Credential Validation** - Validated on every Pod deployment
4. **Containerd 2.0 Ready** - Last release supporting containerd 1.x

### Security Deprecations
- **NGINX Ingress Controller** - Deprecated, migrate to Kubernetes Gateway API
- **AppArmor** - Scheduled for removal in future versions

### New Features
- User namespace support for pod isolation
- Enhanced pod resource limit tracking
- Generation tracking for better audit trails

For detailed security analysis, see [docs/SECURITY_AUDIT_1.35.md](docs/SECURITY_AUDIT_1.35.md).

---

## Vulnerability History

### CVE-2024-48921: Kyverno Policy Exception Privilege Escalation

**Status:** ✅ RESOLVED in v1.35.0
**Severity:** Critical
**Date Fixed:** January 9, 2026

**Details:**
Kyverno versions 1.12 and earlier had policy exceptions enabled by default for all namespaces, allowing potential privilege escalation and policy bypass.

**v1.35.0 Changes:**
- Requires Kyverno v1.13.0 or later
- Explicit policy exception configuration required
- Default deny policies enforced
- Comprehensive policy validation

For upgrade details, see [UPGRADE-1.35.md](UPGRADE-1.35.md#security-changes).

---

## Known Security Issues

### Current Monitoring
- Dependabot actively monitoring go.mod for vulnerabilities
- Zero-day monitoring via GitHub Security Advisory Database
- Regular dependency audits and analysis

### Resolved in Recent Versions
- Outdated Go cryptographic libraries (v1.35.0)
- YAML parsing vulnerabilities (v1.35.0)
- Validation library ReDoS issues (v1.35.0)

For a complete list of resolved issues, see [docs/SECURITY_REMEDIATION_PLAN.md](docs/SECURITY_REMEDIATION_PLAN.md).

---

## Security Audit Timeline

**Monthly Security Reviews:**
- First Monday of each month
- Dependency vulnerability scan
- Security advisory assessment
- Patch release evaluation

**Quarterly Security Audits:**
- Q1: Kubernetes release security review
- Q2: Container/runtime security assessment
- Q3: Network security and compliance review
- Q4: Pre-release comprehensive audit

**Annual Penetration Testing:**
- Comprehensive security assessment
- Threat modeling review
- Incident response validation

---

## Secure Upgrade Path

Before upgrading to v1.35.0, verify:

1. ✅ **Cgroup v2 Ready**
   ```bash
   stat -fc %T /sys/fs/cgroup/
   # Should output: cgroup2fs
   ```

2. ✅ **Container Runtime**
   ```bash
   containerd --version
   # Should be 1.7.0 or later
   ```

3. ✅ **RBAC Policies Updated**
   - Review all pod/exec permissions
   - Update to use `create` verb

4. ✅ **Image Secrets Validated**
   - Test registry credential validation
   - Ensure all credentials are current

5. ✅ **Kyverno v1.13+**
   ```bash
   helm list -n kyverno
   # Verify Kyverno version
   ```

For comprehensive pre-upgrade validation, see [UPGRADE-1.35.md](UPGRADE-1.35.md).

---

## Security Tools & Integration

### Automated Scanning
- **Dependabot:** Go dependency vulnerability scanning
- **GitHub Security:** Advisory tracking and notification
- **Trivy:** Container and configuration scanning
- **GoSec:** Go security linter

### Manual Review Tools
- **go vet:** Go security analysis
- **golangci-lint:** Multi-linter with security checks
- **Nancy:** Go dependency vulnerability checking

### CI/CD Integration
All tools run on:
- Every push to any branch
- Pull request validation
- Release tag verification
- Nightly security scans

---

## Communication & Announcements

### Security Updates
- Announced via GitHub Releases
- Posted to SIGHUP mailing list
- Flagged in release notes
- Prioritized in upgrade guidance

### Security Advisories
- Published on GitHub Security Advisory Database
- Coordinated with security@sighup.io
- Included in SECURITY.md changelog
- Referenced in documentation

### Community Support
- [GitHub Issues](https://github.com/sighupio/distribution/issues) - Bug reports and features
- [GitHub Discussions](https://github.com/sighupio/distribution/discussions) - Security questions
- [SIGHUP Documentation](https://docs.sighup.io/) - Security guides
- security@sighup.io - Vulnerability reports

---

## Contributing Security Fixes

If you want to contribute a security fix:

1. **Do not** open a public pull request for the vulnerability
2. **Email** security@sighup.io with details
3. **Wait** for acknowledgment before coding
4. **Work privately** in a branch
5. **Submit PR** after coordinate disclosure agreement

SIGHUP will work with you to:
- Validate the fix
- Test thoroughly
- Assign credit
- Release promptly
- Publish advisory

---

## Security References

- **CIS Kubernetes Benchmark:** [cisecurity.org](https://www.cisecurity.org/)
- **NIST Cybersecurity Framework:** [nist.gov](https://www.nist.gov/)
- **OWASP Top 10:** [owasp.org](https://owasp.org/)
- **Kubernetes Security Docs:** [kubernetes.io/security](https://kubernetes.io/docs/concepts/security/)
- **Talos Linux Security:** [talos.dev](https://www.talos.dev/)

---

## FAQ

**Q: How often are dependencies updated?**
A: Weekly via Dependabot for security and patch updates. Major version updates reviewed quarterly.

**Q: What is the response time for security issues?**
A: Initial response within 48 hours. Patches released within 7-14 days depending on severity.

**Q: Are signed releases available?**
A: Yes. All releases are GPG-signed. Verify with `git verify-tag v1.35.0`.

**Q: How do I report a vulnerability?**
A: Email security@sighup.io with vulnerability details. Do not create public GitHub issues.

**Q: Which Kubernetes versions does v1.35.0 support?**
A: Kubernetes 1.35.0 and later. See COMPATIBILITY_MATRIX for full details.

---

**Last Updated:** January 9, 2026
**Policy Version:** 1.0.0
**Next Review:** February 9, 2026
