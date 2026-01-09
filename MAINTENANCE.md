# SIGHUP Distribution Maintenance Guide

In this document you can find the steps needed to cook a new release of SD.

Some things to know before starting:

- We maintain the latest 3 "minor" versions of SD so, when you release a new version, you usually need to actually release 3 new versions. See the [versioning](docs/VERSIONING.md) file for more details if you are not familiar with SD's versioning.
- Each release of SD is tightly coupled with a release of `furyctl`. So you'll need to be able to update furyctl too, or ask for help from somebody that can.

Usually, a new release of SD is triggered by one of these events:

- One or more core modules have been updated (new versions have been released), could be a bug fix or a simple bump of version to add new features.
- A new version with a bug fix or new features of one or more of the installers (on-premises, EKS, etc.) has been released.
- A new feature or a bug fix has been introduced into the template files of the distribution.
- A new release of Kubernetes is out and must be supported (usually triggers all the 3 previous points).

The release is needed to render this updates available to SD's user base.

## CI/CD Pipeline Triggers

Different tag patterns trigger specific combinations of test pipelines to optimize CI resource usage and testing coverage:

| Tag Pattern                 | Pipelines Triggered                                                           |
| --------------------------- | ----------------------------------------------------------------------------- |
| **Any push**                | QA only                                                                       |
| **`e2e-all-*`**             | QA + ALL e2e tests (kfddistro, eks, eks-selfmanaged, onpremises) - NO release |
| **`e2e-eks-*`**             | QA + ALL EKS e2e only (standard + selfmanaged + upgrades)                     |
| **`e2e-kfddistribution-*`** | QA + kfddistro e2e only                                                       |
| **`e2e-onpremises-*`**      | QA + onpremises e2e only                                                      |
| **`v1.XX.X`**               | QA + ALL e2e EXCEPT selfmanaged → release (stable)                            |
| **`v1.XX.X-rc.X`**          | QA + ALL e2e EXCEPT selfmanaged → release (prerelease)                        |

## Process

The update process usually involves going back and forward between SD (this repo) and furyctl.

> [!NOTE]
> Some of the following steps may not apply in some specific cases, for example if you are only releasing a patch version that fixes an issue on the templates, maybe you can skip some steps.

With no further ado, the steps to release a new version are:

### fury-distribution

> [!WARNING]
> If you are releasing a new `x.y.0` version create a `release-vX.<y-1>` branch for the previous release.

1. Create a new branch `feat/vx.y.z` (`v1.29.4`, for example) where to work on.
2. Create the PRs fixing the issues or adding new features to the templates or other files of fury-distribution, test them and merge them.
3. Update the `kfd.yaml` and `Furyfile.yaml` files, bumping the distribution version, adjusting the modules and installers versions where needed.
4. If the distribution schemas have been changed:
   1. If you haven't already, install the needed tools with `mise install`.
   2. Generate the new docs with `mise run generate-docs`.
   3. Generate the go models with `mise run generate-go-models`
5. Update the CI and e2e tests to point to the new version:
   1. `.drone.yaml`
   2. `tests/e2e-kfddistribution-*.yaml`
   3. `tests/e2e-kfddistribution-upgrades.sh`
   4. `tests/e2e/kfddistribution-upgrades/furyctl-init-cluster-1.29.4.yaml`
6. Update the documentation:
   1. `README.md`
   2. `docs/COMPATIBILITY_MATRIX.md`
   3. `docs/VERSIONING.md`
   4. Write the release notes for the new version (`docs/releases/vx.y.z.md`)
7. Tag a release candidate to trigger all the e2e tests and fix eventual problems

At this point, you'll need to switch to pushing some changes in furyctl

### furyctl

8. Create a new branch for the WIP release like `feat/vx.y.z` (`v0.29.8`, for example)
9. Add the new versions to the `internal/distribution/compatibility.go` file.
10. Add the migration paths to the corresponding kinds in `configs/upgrades/{onpremises,kfddistribution,ekscluster}/`, creating the needed folders for each new version.
11. Update the documentation:
    1. `README.md`.
    2. `docs/COMPATIBLITY_MATRIX.md`.
12. Update the compatibility unit tests with the new versions (`internal/distribution/compatibility_test.go`)
13. Bump the version to the new `fury-distribution` go library that has been released as RC in step `7`.

```bash
go get -u github.com/sighupio/fury-distribution@v1.29.4
go mod tidy
```

14. Tag a release candidate with the changes. This will be used in the e2e tests of the distribution.

### Back to fury-distribution

15. Update the CI's `.drone.yaml` file to use the release candidate for furyctl that you released in step `14`.
16. Update the e2e tests with the new upgrade paths.
17. Tag a new release candidate of the distribution to run the e2e tests using the new upgrade paths and furyctl's RC.
18. After the CI passes and the PR has been approved, merge into `main`
19. Tag the final release and let the CI run again and do the release.
20. **Repeat all the process for the other 2 "minor" versions that need to be updated**, but targeting `release-vx.y` branches instead of `main`.

### Back to furyctl

21. Once SD new releases are live and the PR with the update to furyctl has been approved, merge and tag the final release.

### Other changes

After the release of the distribution and furyctl have been done, there are some other places that need to be updated to reflect the new releases, in no particular order:

1. Update the quick-start guides in https://github.com/sighupio/getting-started/
2. Update SD's documentation site with the new versions https://github.com/sighupio/docs/
3. Run the CVE patching pipeline by adding the newly released SIGHUP versions https://github.com/sighupio/container-image-sync/

## Support Timeline and Version Management

SIGHUP Distribution follows a **3-minor-version support window** aligned with Kubernetes releases. Each minor Kubernetes version release is supported for approximately 9 months from its release date.

### Kubernetes 1.35 Support Schedule

| Version | Release Date | Support Status | Support Window | EOL Date |
|---------|-------------|---|---|---|
| **v1.35.x** | December 17, 2025 | **Current (Stable)** | Full support | ~September 2026 |
| **v1.34.x** | September 2025 | Maintenance | Extended support | ~June 2026 |
| **v1.33.x** | June 2025 | Legacy | Critical patches only | ~March 2026 |
| v1.32.x | March 2025 | Unsupported | No updates | January 2026 |

### v1.35.0 Release Details

**Release Date:** January 2026 (planned)
**Target Kubernetes:** v1.35.0+
**Status:** Pre-release (RC phase completed)

**Key Changes for Operations Teams:**
- **Mandatory Cgroup v2** - All nodes must be on cgroup v2 (not optional in v1.35)
- **IPVS Deprecation** - Migration to nftables mode strongly recommended
- **Containerd 2.0 Support** - v1.35 is the last release supporting containerd 1.x
- **RBAC Policy Updates** - pod/exec, pod/attach, pod/portforward require `create` verb
- **Image Pull Validation** - Credentials validated on every Pod, even for cached images

### Release Timeline for v1.35

| Phase | Timeframe | Activity | Responsible Team |
|-------|-----------|----------|-----------------|
| **Phase 1: Prep** | 3-4 weeks pre-release | Cgroup v2 upgrade, infrastructure readiness | Platform Engineering |
| **Phase 2: Dev & Test** | 2-3 weeks | Manifest updates, staging deployment, e2e tests | Development Team |
| **Phase 3: Docs & Release** | 1-2 weeks | Security audit, documentation, release notes | Product/Security Team |
| **Phase 4: Release** | 1 week | Tag release, publish artifacts, communications | Release Manager |
| **Phase 5: Rollout** | 4+ weeks | Customer adoption, patch releases, support | Support Team |

### Pre-Upgrade Checklist for v1.35

**Before scheduling your upgrade to v1.35, verify:**

1. ✅ **Cgroup v2 Ready** - All nodes running cgroup v2 (`stat -fc %T /sys/fs/cgroup/` shows `cgroup2fs`)
2. ✅ **Container Runtime** - containerd 1.7+ installed (plan upgrade to 2.0+ post-1.35)
3. ✅ **RBAC Audit** - All pod/exec permissions updated to use `create` verb
4. ✅ **Image Secrets** - All registry credentials valid and non-expired
5. ✅ **Network Proxy** - Document current proxy mode (IPVS vs iptables/nftables)
6. ✅ **Module Compatibility** - Confirm all operators support Kubernetes 1.35

See [UPGRADE-1.35.md](./UPGRADE-1.35.md) for comprehensive pre-upgrade validation steps.

### Version-Specific Documentation

- **v1.35 Upgrade Guide:** [UPGRADE-1.35.md](./UPGRADE-1.35.md) - Detailed breaking changes and migration steps
- **v1.34 Upgrade Guide:** [UPGRADE-1.34.md](./UPGRADE-1.34.md) - Previous upgrade documentation
- **Compatibility Matrix:** [docs/COMPATIBILITY_MATRIX.md](./docs/COMPATIBILITY_MATRIX.md) - Module version compatibility per Kubernetes version
- **Security Audit:** [docs/SECURITY_AUDIT_1.35.md](./docs/SECURITY_AUDIT_1.35.md) - Security review of v1.35 changes

### Planning Your Upgrade

**Early Adopters** (January-February 2026)
- Test v1.35 in non-production environments
- Participate in feedback and issue reporting
- Help identify edge cases and problems

**Production Deployments** (February-April 2026)
- After initial stability validation
- Use v1.34 LTS as fallback if issues found
- Plan maintenance windows for cgroup v2 upgrade

**Legacy Systems** (May+ 2026)
- Continue on v1.33 if v1.35 incompatibilities found
- Plan longer migration timeline
- Request extended support if needed

### Patch Release Schedule

After v1.35.0 release:

- **v1.35.1+** - Monthly patch releases (security + critical bugs)
- **v1.34.x** - Maintenance patches until June 2026
- **v1.33.x** - Critical security patches only until March 2026

### Support Communication

- **Release Announcements:** GitHub releases, SIGHUP mailing list
- **Known Issues:** Updated in [UPGRADE-1.35.md](./UPGRADE-1.35.md#known-issues-and-workarounds)
- **Security Issues:** Reported to security@sighup.io, patched via CVE process
- **Migration Help:** [Community forums](https://github.com/sighupio/distribution/discussions), GitHub issues

For questions or concerns about upgrading to v1.35, see [docs/FAQ.md](./docs/FAQ.md) or contact SIGHUP support.
