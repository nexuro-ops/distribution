# Kubernetes 1.33 → 1.34 Upgrade Guide for SIGHUP Distribution

## Overview

SIGHUP Distribution is a modular, CNCF-certified Kubernetes distribution currently targeting **Kubernetes 1.33.x**. This guide provides a comprehensive roadmap for upgrading to Kubernetes 1.34.

The upgrade is relatively straightforward since Kubernetes 1.34 does not introduce major API removals, but several deprecations and behavior changes require careful attention.

---

## Critical Breaking Changes

### 1. Container Image Name Resolution (CRI-O Runtime)

**Impact: HIGH**

If using CRI-O runtime, short image names like `nginx:latest` are no longer accepted. Kubernetes 1.34 requires fully qualified registry paths.

**Required Actions:**
- Ensure all container images use fully qualified registry paths
- Update manifests across all modules:
  - `templates/distribution/manifests/ingress/`
  - `templates/distribution/manifests/logging/`
  - `templates/distribution/manifests/monitoring/`
  - `templates/distribution/manifests/tracing/`
  - `templates/distribution/manifests/auth/`
  - `templates/distribution/manifests/policy/`
  - `templates/distribution/manifests/networking/`

**Example Changes:**
```yaml
# Before
image: nginx:latest
image: prometheus:latest

# After (with registry prefix)
image: docker.io/library/nginx:latest
image: docker.io/prom/prometheus:latest
# Or use your private registry:
image: registry.example.com/nginx:latest
```

**Script to Find Short Names:**
```bash
# Find all image references without registry prefixes
find templates/ -name "*.yaml" -o -name "*.tpl" | xargs grep -E "image:\s+[a-zA-Z0-9_-]+:[0-9a-zA-Z.-]+" | grep -v "/"
```

### 2. Pod Topology Spread Constraints (matchLabelKeys)

**Impact: MEDIUM**

Scheduler behavior with `matchLabelKeys` in `topologySpreadConstraints` has changed between 1.33 and 1.34.

**Required Actions:**
- Must upgrade directly from 1.33 → 1.34 (no intermediate versions)
- Validate any pods using `topologySpreadConstraints` with `matchLabelKeys`
- Test pod scheduling behavior in staging environment before production

**Files to Review:**
- Network policy definitions
- Pod disruption budget configurations
- Custom kustomize patches affecting pod scheduling

### 3. Cgroup Driver Configuration Deprecation

**Impact: MEDIUM** (Removal planned for v1.36+)

Manual `cgroupDriver` configuration in kubelet configuration files is deprecated. Kubernetes 1.34 encourages automatic cgroup driver detection.

**Required Actions:**
- Remove hardcoded `--cgroup-driver` flags from kubelet configuration
- Rely on automatic cgroup driver detection instead
- Test automatic cgroup detection in staging environment before production

**Where to Check:**
- Kubernetes deployment configuration for control plane and worker nodes
- On-premises installer: `templates/distribution/terraform/`
- Any custom kubelet configuration files

---

## Deprecations to Prepare For

### 1. AppArmor Deprecation

**Impact: LOW** (Removal not before v1.36+)

AppArmor support is deprecated but still functional in 1.34.

**Recommended Actions:**
- Audit if any pod security policies or custom configurations use AppArmor
- Begin planning migration to alternatives (seccomp, SELinux)
- Update documentation about AppArmor usage
- No immediate action required, but plan ahead

### 2. Containerd Version Support Timeline

**Impact: LOW-MEDIUM**

Containerd 1.7 and 1.X are on extended support timeline, with plan to move toward 2.0+.

**Recommended Actions:**
- Document containerd version requirements
- Plan migration to containerd 2.0+ for future releases
- Update CI/CD testing to include latest containerd versions
- No immediate action needed

---

## Version-Specific Updates Required

### Module Component Compatibility Matrix

Review and validate compatibility of all module components with Kubernetes 1.34:

| Module | Current Version | Status | Action Required |
|--------|-----------------|--------|-----------------|
| NGINX Ingress Controller | v4.1.1 | ⚠️ Check | Verify 1.34 compatibility |
| Cert-Manager | Latest | ✅ Compatible | No immediate action |
| PrometheusOperator | v4.0.1 | ⚠️ Check | Validate CRD versions |
| LoggingOperator | v5.2.0 | ⚠️ Check | Test with 1.34 |
| Gatekeeper/Kyverno | v1.15.0 | ⚠️ Check | Validate policy CRDs |
| Velero | v3.2.0 | ⚠️ Check | Confirm API compatibility |
| Calico/Cilium CNI | Latest | ⚠️ Check | Verify network policy support |
| AWS Load Balancer Controller | v5.1.0 | ⚠️ Check | Test with 1.34 APIs |
| External DNS | Latest | ⚠️ Check | Verify annotation compatibility |
| Prometheus | Latest | ⚠️ Check | Test metrics collection |
| Grafana | Latest | ✅ Compatible | No immediate action |
| AlertManager | Latest | ⚠️ Check | Verify alert routing |
| EBS CSI Driver | Latest | ⚠️ Check | AWS-specific validation |

**Action:** Check each operator's GitHub repository and documentation for official 1.34 support statement.

### CRD and API Version Updates

SIGHUP Distribution defines custom resources that must be validated:

**CRDs to Review:**
- `KFDDistribution` (v1alpha2) - `schemas/public/kfddistribution-kfd-v1alpha2.json`
- `EKSCluster` (v1alpha2) - `schemas/public/ekscluster-kfd-v1alpha2.json`
- `OnPremises` (v1alpha2) - `schemas/public/onpremises-kfd-v1alpha2.json`
- Custom patches - `schemas/public/spec-distribution-custompatches.json`
- Plugin configuration - `schemas/public/spec-plugins.json`

**Required Actions:**
- Validate all CRD schemas work with Kubernetes 1.34 API server
- Test custom resource validation with new API server version
- Review schema files for any deprecated API versions
- Run `kubectl api-versions` against test 1.34 cluster to verify registered versions

### Kustomize Patches and Strategic Merge Patches

With 21 kustomization.yaml files and multiple patch strategies:

**Required Actions:**
- Review all patch strategies for compatibility with new API behaviors
- Test manifest generation with `kustomize build` against Kubernetes 1.34 schema
- Validate custom patches don't conflict with new API field requirements
- Test JSON patches, strategic merge patches, and overlay patches

**Key Locations:**
- `templates/distribution/manifests/*/kustomization.yaml` (21 files)
- `templates/distribution/manifests/*/patches/` directories
- Custom overlay configurations

---

## Specific Implementation Changes

### 1. Update All Image References (CRITICAL)

**Priority: CRITICAL - Required for CRI-O compatibility**

All container image references must include a registry prefix.

**Files to Update:**

Create a script to audit and update image references:

```bash
#!/bin/bash
# find-short-images.sh - Identify short image references

echo "=== Scanning for short image references ==="
find templates/distribution/manifests -type f \( -name "*.yaml" -o -name "*.yml" \) | while read file; do
  if grep -q "image:\s*[a-zA-Z0-9_-]*:[0-9a-zA-Z.-]*$" "$file"; then
    echo "File: $file"
    grep "image:" "$file" | grep -v "/" || true
  fi
done
```

**Common Updates Needed:**

```yaml
# Ingress Module
ingress-nginx/controller: docker.io/library/nginx:latest
cert-manager-webhook: quay.io/jetstack/cert-manager-webhook:latest
external-dns: registry.k8s.io/external-dns/external-dns:latest

# Logging Module
fluent-bit: fluent/fluent-bit:latest
fluentd: fluent/fluentd:latest
opensearch: opensearchproject/opensearch:latest

# Monitoring Module
prometheus: quay.io/prometheus/prometheus:latest
grafana: grafana/grafana:latest
alertmanager: quay.io/prometheus/alertmanager:latest

# Tracing Module
tempo: grafana/tempo:latest

# Policy Module (Gatekeeper)
gatekeeper: openpolicyagent/gatekeeper:latest

# Auth Module
pomerium: pomerium/pomerium:latest
dex: ghcr.io/dexidp/dex:latest
```

### 2. Update Installation Tools Version (mise.toml)

Update tool versions to ensure compatibility with Kubernetes 1.34:

```toml
# tools/Go.env
[tools.go]
version = "1.23.3"  # Keep current or upgrade if 1.34 requires it

# tools/kubectl
[tools.kubectl]
version = "1.34.x"  # Update from 1.33.x

# tools/kustomize
[tools.kustomize]
version = "5.6.0"  # Verify compatibility, update if needed

# tools/helm
[tools.helm]
version = "3.12.3"  # Verify compatibility, update if needed

# tools/helmfile
[tools.helmfile]
version = "0.156.0"  # Verify compatibility, update if needed
```

### 3. Update CI/CD Testing (.drone.yml)

Add comprehensive Kubernetes 1.34 testing:

**Actions:**
- Add test tags for 1.34: `e2e-all-1.34`, `e2e-eks-1.34`, `e2e-kfddistribution-1.34`, `e2e-onpremises-1.34`
- Update kind images to 1.34 base images
- Add version skew tests between 1.33 and 1.34
- Test upgrade path 1.33 → 1.34 in e2e tests
- Validate all modules work correctly with 1.34

**Example drone.yml additions:**
```yaml
- name: e2e-1.34-eks
  image: drone/drone-runner-docker:latest
  environment:
    KUBERNETES_VERSION: "1.34.x"
    CLUSTER_TYPE: "eks"
  commands:
    - ./scripts/e2e-test.sh

- name: e2e-1.34-kfddistribution
  image: drone/drone-runner-docker:latest
  environment:
    KUBERNETES_VERSION: "1.34.x"
    CLUSTER_TYPE: "kfddistribution"
  commands:
    - ./scripts/e2e-test.sh
```

### 4. Update Version Mappings (kfd.yaml)

Add Kubernetes 1.34 version mappings:

```yaml
kubernetesVersions:
  - kubernetesVersion: "1.34"
    distributionVersion: "1.34.0"
    supported: true
    modules:
      ingress:
        version: "v4.1.1"  # or updated version verified for 1.34
      networking:
        version: "v3.0.0"  # or updated version
      logging:
        version: "v5.2.0"  # or updated version
      monitoring:
        version: "v4.0.1"  # or updated version
      tracing:
        version: "v1.3.0"  # or updated version
      policy:
        version: "v1.15.0"  # or updated version
      auth:
        version: "v0.6.0"  # or updated version
      disasterRecovery:
        version: "v3.2.0"  # or updated version
      aws:
        version: "v5.1.0"  # or updated version
```

### 5. Update Documentation

**Files to Update:**

1. **README.md** - Add 1.34 support information
   ```markdown
   ## Supported Kubernetes Versions

   SIGHUP Distribution supports the following Kubernetes versions:
   - Kubernetes 1.34.x (Latest)
   - Kubernetes 1.33.x
   - Kubernetes 1.32.x
   ```

2. **MAINTENANCE.md** - Update maintenance timeline
   ```markdown
   ## Kubernetes Version Support Timeline

   - SD v1.34.x: Kubernetes 1.34 (current)
   - SD v1.33.x: Kubernetes 1.33 (maintenance)
   - SD v1.32.x: Kubernetes 1.32 (extended maintenance)
   ```

3. **ROADMAP.md** - Update release schedule
   ```markdown
   ### Q4 2025
   - [ ] Release SD v1.34.0 targeting Kubernetes 1.34
   - [ ] Full module compatibility validation
   - [ ] Migration guide 1.33 → 1.34
   ```

4. **docs/upgrade-1.33-to-1.34.md** - Create dedicated upgrade guide

### 6. Update go.mod Dependencies

Verify Go dependencies are compatible with 1.34:

```bash
# Commands to run
go mod tidy
go get -u k8s.io/kubernetes@v1.34.0
go get -u k8s.io/api@v1.34.0
go get -u k8s.io/apimachinery@v1.34.0
go get -u k8s.io/client-go@v1.34.0

# Then validate builds
go build ./...
go test ./...
```

---

## Pre-Upgrade Checklist

- [ ] **Image References:** All container images have fully qualified registry paths
- [ ] **Pod Topology:** All topologySpreadConstraints validated; no problematic matchLabelKeys
- [ ] **Cgroup Driver:** Kubelet cgroup driver detection tested; manual flags removed
- [ ] **AppArmor Audit:** Checked if AppArmor is used; migration plan created
- [ ] **Module Versions:** Verified all operator versions work with Kubernetes 1.34
  - [ ] NGINX Ingress Controller
  - [ ] PrometheusOperator
  - [ ] LoggingOperator
  - [ ] Gatekeeper/Kyverno
  - [ ] Velero
  - [ ] CNI (Calico/Cilium)
  - [ ] AWS Load Balancer Controller
- [ ] **CRD Schemas:** All custom resource schemas validated against 1.34 API
- [ ] **Kustomize Patches:** All patch strategies tested with Kubernetes 1.34 schema
- [ ] **CI/CD Tests:** 1.34 test tags added and passing
- [ ] **Tool Versions:** Updated mise.toml, kubectl, kustomize, helm versions
- [ ] **Staging Environment:** Full distribution deployed and tested on 1.34
- [ ] **Disaster Recovery:** Velero backups tested with 1.34
- [ ] **Network Policies:** All 27+ network policy files validated
- [ ] **Documentation:** README, MAINTENANCE.md, ROADMAP.md updated
- [ ] **Release Notes:** Draft release notes prepared for v1.34.0
- [ ] **Backward Compatibility:** Verified 1.33 clusters can upgrade to 1.34
- [ ] **Performance Baseline:** Established performance metrics before upgrade

---

## Recommended Upgrade Path

### Phase 1: Preparation and Development (2-3 weeks)

1. Create feature branch: `upgrade/kubernetes-1.34`
2. Update all image references with registry prefixes
3. Update go.mod and validate builds
4. Update mise.toml with compatible tool versions
5. Update kfd.yaml with 1.34 mappings
6. Add CI/CD tests for 1.34
7. Test all modules individually in staging

### Phase 2: Integration Testing (2-3 weeks)

1. Deploy full distribution to Kubernetes 1.34 staging cluster
2. Run comprehensive e2e test suite
3. Validate module interactions and networking
4. Test disaster recovery and backup/restore
5. Performance testing and baseline establishment
6. Security scanning and vulnerability assessment
7. Test upgrade path from existing 1.33 clusters

### Phase 3: Documentation and Validation (1 week)

1. Complete upgrade guide documentation
2. Create migration runbook for customers
3. Record known issues and workarounds
4. Prepare release notes
5. Security audit of 1.34 changes
6. Final stakeholder approval

### Phase 4: Release (1 week)

1. Merge feature branch to main
2. Create release branch: `release/v1.34.0`
3. Tag release: `v1.34.0`
4. Build and publish release artifacts
5. Update distribution documentation
6. Announce release to community

### Phase 5: Customer Rollout (Ongoing)

1. Communicate upgrade availability
2. Provide upgrade instructions to customers
3. Monitor early adopter clusters for issues
4. Publish security bulletins if needed
5. Plan patch releases (v1.34.1, etc.)

---

## Testing Strategy

### Unit Tests
```bash
go test ./pkg/...
go test ./...
```

### Integration Tests with kind
```bash
# Create 1.34 cluster
kind create cluster --image kindest/node:v1.34.0

# Deploy distribution
./scripts/deploy-distribution.sh

# Run tests
./scripts/run-e2e-tests.sh
```

### E2E Testing Matrix
- [ ] EKS with 1.34
- [ ] KFDDistribution (self-managed) with 1.34
- [ ] On-premises bare-metal with 1.34
- [ ] Each module individually
- [ ] All modules together
- [ ] Upgrade from 1.33 → 1.34
- [ ] Multi-cluster scenarios

### Performance Testing
```bash
# Establish baseline before upgrade
./scripts/perf-baseline.sh

# After upgrade, compare metrics
./scripts/perf-test.sh
```

---

## Rollback Plan

In case of issues with 1.34:

1. **Immediate Rollback:** Keep 1.33.x branch updated with patches
2. **Version Skew:** Support running 1.33 control plane with 1.34 workers (if needed)
3. **Restore from Backup:** Have Velero backups from 1.33 available
4. **Known Issues Document:** Maintain list of discovered issues and workarounds

---

## Important References

### Official Kubernetes Resources
- [Kubernetes 1.34 Release Notes](https://kubernetes.io/blog/2025/08/27/kubernetes-v1-34-release/)
- [Kubernetes 1.34 Changelog](https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG/CHANGELOG-1.34.md)
- [Kubernetes Version Skew Policy](https://kubernetes.io/docs/setup/release/version-skew-policy/)

### Breaking Changes and Deprecations
- [Image Name Resolution Breaking Changes](https://www.replicated.com/blog/breaking-change-kubernetes-1-34-tightens-image-name-resolution-rules----what-it-means-for-you)
- [Kubernetes 1.33 vs 1.34 Analysis](https://user-cube.medium.com/kubernetes-1-33-vs-1-34-whats-new-what-changed-and-why-it-matters-e60e3cdaffa3)
- [Fairwinds 1.34 Upgrade Guide](https://www.fairwinds.com/blog/kubernetes-1-34-released-whats-new-upgrade)

### Module-Specific Resources
- Update links to each module's official documentation for 1.34 compatibility

---

## Contact and Support

For questions or issues related to this upgrade guide:
1. Check the [Known Issues](#known-issues) section (to be populated)
2. Review module-specific documentation
3. Open an issue on GitHub with the `upgrade` label
4. Contact SIGHUP team for enterprise support

---

## Known Issues

(To be populated as issues are discovered during testing)

| Issue | Workaround | Status |
|-------|-----------|--------|
| Example issue | Example workaround | Under investigation |

---

**Last Updated:** 2026-01-09
**Target Release:** SD v1.34.0
**Kubernetes Version:** 1.34.x
