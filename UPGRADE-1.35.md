# Kubernetes 1.34 → 1.35 Upgrade Guide for SIGHUP Distribution

## Overview

SIGHUP Distribution v1.35 targets **Kubernetes 1.35** (released December 17, 2025, codename "Timbernetes").

This is a more significant upgrade than 1.33 → 1.34, with several **critical breaking changes** that must be addressed before upgrading:

1. **Cgroup v2 is now mandatory** - Cgroup v1 support removed entirely
2. **IPVS mode deprecated** - Migration to nftables required for future compatibility
3. **containerd 1.x support ends** - Must upgrade to containerd 2.0+ before v1.36
4. **WebSocket RBAC changes** - `kubectl exec` now requires `create` permissions
5. **Image pull credential verification** - Credentials re-validated on every Pod

This guide provides a comprehensive roadmap for planning and executing this upgrade.

---

## Critical Breaking Changes

### 1. Cgroup v2 is Now Mandatory (BLOCKER)

**Impact: CRITICAL - Upgrade will fail without this**

Kubernetes 1.35 removes all cgroup v1 support. The kubelet will fail to start on nodes using cgroup v1. This is **not a graceful deprecation** - it's a hard requirement.

**What You Need to Do:**

Before upgrading ANY component to Kubernetes 1.35, verify and upgrade all nodes to cgroup v2.

**Check Current Cgroup Version:**

```bash
# On each node, verify cgroup version
stat -fc %T /sys/fs/cgroup/

# Output: cgroup2fs   (cgroup v2 - OK)
# Output: tmpfs       (cgroup v1 - MUST UPGRADE)

# Alternative check
grep cgroup /proc/filesystems
# Should show: cgroup2
```

**Upgrading from Cgroup v1 to v2:**

This typically requires upgrading to a newer Linux distribution that defaults to cgroup v2:

```bash
# For Ubuntu/Debian
# Ubuntu 22.04 LTS and later default to cgroup v2
# Ubuntu 20.04 uses cgroup v1

# For CentOS/RHEL
# CentOS/RHEL 9+ default to cgroup v2
# CentOS/RHEL 8 uses cgroup v1

# For other distributions, enable cgroup v2 via boot parameters:
# GRUB: systemd.unified_cgroup_hierarchy=1
```

**Procedure for On-Premises Clusters:**

```bash
# 1. Create new nodes with cgroup v2 support
#    - Use newer OS image
#    - Verify cgroup v2 before adding to cluster

# 2. Cordon and drain old cgroup v1 nodes
kubectl cordon node-v1-1
kubectl drain node-v1-1 --ignore-daemonsets --delete-emptydir-data

# 3. Remove from cluster
kubectl delete node node-v1-1

# 4. Decommission old nodes

# 5. Repeat for all nodes
```

**Procedure for EKS Clusters:**

```bash
# 1. Check EKS launch template
# Ensure AMI is built with cgroup v2

# 2. Create new node group with cgroup v2 AMI
aws eks create-nodegroup \
  --cluster-name your-cluster \
  --nodegroup-name workers-v2 \
  --ami-type AL2_x86_64 \
  # Ensure AMI supports cgroup v2

# 3. Cordon old nodes
kubectl cordon node-v1-1 node-v1-2 node-v1-3

# 4. Drain old nodes
kubectl drain node-v1-1 --ignore-daemonsets --delete-emptydir-data

# 5. Delete old node group via AWS console or CLI
```

**Files to Update in SIGHUP Distribution:**

- `templates/distribution/terraform/eks/` - Update AMI selection
- `templates/distribution/terraform/onpremises/` - Update OS image references
- `defaults/ekscluster-kfd-v1alpha2.yaml` - Document cgroup v2 requirement
- `defaults/onpremises-kfd-v1alpha2.yaml` - Document cgroup v2 requirement

### 2. IPVS Mode Deprecation

**Impact: MEDIUM** (Still works in 1.35, but removal targeted for v1.38)

IPVS mode in kube-proxy is now formally deprecated. The SIG Network team recommends migrating to nftables mode.

**Current Status:**
- v1.35: Still functional, deprecation warning on startup
- v1.36-v1.37: Still supported, strong warnings
- v1.38+: Expected removal

**Check if IPVS is Used:**

```bash
# Check DaemonSet config
kubectl get daemonset -n kube-system kube-proxy -o yaml | grep -A5 "proxy-mode"

# Check running mode
kubectl logs -n kube-system -l k8s-app=kube-proxy | grep "proxy_mode"

# If output contains "ipvs" - must plan migration
```

**Migration to nftables:**

```yaml
# Update kube-proxy ConfigMap
# From:
kind: ConfigMap
metadata:
  name: kube-proxy-config
data:
  kubeconfig.conf: ...
  config.conf: |
    mode: "ipvs"
    # ... other settings

# To:
kind: ConfigMap
metadata:
  name: kube-proxy-config
data:
  kubeconfig.conf: ...
  config.conf: |
    mode: "nftables"
    # ... other settings
```

**Files to Update in SIGHUP Distribution:**

- `templates/distribution/manifests/networking/kube-proxy/` - Update kube-proxy configuration
- Update default mode to nftables in configuration schemas

### 3. Containerd 1.x Support Ends (Critical for Future)

**Impact: HIGH** (Not blocking in 1.35, but required before v1.36)

Kubernetes 1.35 is the **final version supporting containerd 1.x**. This is your last chance to migrate before the next release.

**Key Changes in containerd 2.0:**
- Removes Docker Schema v1 image support
- Updated API and configuration format
- Improved stability and performance
- Requires kubelet config updates

**Check containerd Version:**

```bash
# On each node
containerd --version

# Output example:
# containerd github.com/containerd/containerd v1.7.0
# OR
# containerd github.com/containerd/containerd v2.0.0
```

**Create containerd 2.0 Migration Plan:**

```bash
# 1. Audit container images in use
kubectl get pods --all-namespaces -o jsonpath='{..image}' | tr ',' '\n' | sort | uniq

# 2. Check for Docker Schema v1 images (rare but possible)
# These images will fail to pull with containerd 2.0

# 3. Schedule upgrade window for each node
# Containerd upgrade typically causes container restarts

# 4. Update containerd configuration
# Config file locations:
# - /etc/containerd/config.toml
# - ~/.containerd/config.toml
```

**Upgrade Procedure:**

```bash
# On each node (one at a time)
# 1. Cordon node
kubectl cordon node-x

# 2. Drain node
kubectl drain node-x --ignore-daemonsets --delete-emptydir-data

# 3. Upgrade containerd
sudo systemctl stop kubelet
sudo systemctl stop containerd

# Debian/Ubuntu
sudo apt-get install containerd=2.0.0+

# RHEL/CentOS
sudo yum install containerd-2.0.0+

# 4. Update config.toml if needed
# Many configs are backward compatible

# 5. Start containerd and kubelet
sudo systemctl start containerd
sudo systemctl start kubelet

# 6. Verify pods restart correctly
kubectl wait --for=condition=Ready pod -l app=my-app -n default

# 7. Uncordon node
kubectl uncordon node-x
```

**Files to Update in SIGHUP Distribution:**

- `mise.toml` - Update containerd version requirement
- Update CI/CD to test with containerd 2.0
- Add migration guide to documentation

### 4. WebSocket RBAC Changes

**Impact: MEDIUM** (Affects `kubectl exec`, `kubectl attach`)

Interactive commands like `kubectl exec` now require `create` permission on pod subresources (pods/exec, pods/attach, pods/portforward) for **both SPDY and WebSocket API requests**.

Previously:
- SPDY requests required `create` permission
- WebSocket requests only required `get` permission

Now:
- Both require `create` permission

**Check Current RBAC Policies:**

```bash
# Find roles with pod exec/attach permissions
kubectl get clusterroles -o json | jq '.items[] | select(.rules[]? | select(.verbs[]? | select(. == "get")) and .resources[]? | select(. == "pods/exec")) | .metadata.name'

# Check if roles grant "get" but not "create"
kubectl get clusterrole my-role -o yaml | grep -A10 "pods/exec"
```

**Update RBAC Policies:**

```yaml
# Before (insufficient for v1.35)
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: pod-reader
rules:
- apiGroups: [""]
  resources: ["pods", "pods/log"]
  verbs: ["get", "list"]
- apiGroups: [""]
  resources: ["pods/exec", "pods/attach", "pods/portforward"]
  verbs: ["get"]  # ❌ NO LONGER SUFFICIENT

# After (compatible with v1.35)
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: pod-reader
rules:
- apiGroups: [""]
  resources: ["pods", "pods/log"]
  verbs: ["get", "list"]
- apiGroups: [""]
  resources: ["pods/exec", "pods/attach", "pods/portforward"]
  verbs: ["create"]  # ✅ REQUIRED
```

**Files to Update in SIGHUP Distribution:**

- `templates/distribution/manifests/auth/` - Update Pomerium and Dex RBAC roles
- Review any custom RBAC configurations
- Update documentation about exec permissions

### 5. Image Pull Credential Verification

**Impact: MEDIUM**

Kubernetes 1.35 now enforces credential verification for every Pod, even for cached images. Previously, credentials were only verified on first pull.

**What This Means:**

```yaml
# Scenario: Pod pulls private image, credentials expire, Pod still running
# Before v1.35: Pod continues running, no issue
# After v1.35: Next scheduler event or pod restart fails with ImagePullBackOff

spec:
  imagePullSecrets:
  - name: my-registry-secret  # ❌ If expired, image pull fails even if cached
```

**Pre-Upgrade Actions:**

```bash
# 1. Audit image pull secrets
kubectl get secrets --all-namespaces -o json | jq '.items[] | select(.type == "kubernetes.io/dockercfg" or .type == "kubernetes.io/dockerconfigjson") | {namespace: .metadata.namespace, name: .metadata.name}'

# 2. Check expiration dates in docker config
# Decode secret and check credentials

# 3. Rotate expiring secrets before upgrade
kubectl create secret docker-registry my-registry-secret \
  --docker-server=registry.example.com \
  --docker-username=user \
  --docker-password=newpassword \
  --docker-email=user@example.com \
  -n my-namespace --dry-run=client -o yaml | kubectl apply -f -
```

**Files to Update in SIGHUP Distribution:**

- Documentation about image pull secret management
- Update deployment scripts to rotate secrets before upgrade

---

## Deprecations to Prepare For

### 1. NGINX Ingress Controller Deprecation

**Impact: HIGH** (Archival timeline: March 2026)

The NGINX Ingress Controller is being archived and will receive no updates after March 2026. This is not an immediate blocker, but plan migration to Gateway API.

**Migration Path:**

```bash
# 1. Audit current Ingress resources
kubectl get ingress --all-namespaces

# 2. Use ingress2gateway tool to convert
# https://github.com/kubernetes-sigs/ingress2gateway
ingress2gateway --ingress-class=nginx --output-dir=./gateway-manifests/

# 3. Review generated Gateway API manifests
kubectl apply -f ./gateway-manifests/

# 4. Install Gateway API controller
# Multiple options:
# - Contour
# - Cilium Gateway API
# - Kong Gateway
# - Istio Gateway
# - GKE Gateway Controller (AWS, GCP, Azure, etc.)

# 5. Test Gateway API routes
kubectl apply -f test-gateway-route.yaml
kubectl get httproutes

# 6. Decommission NGINX Ingress Controller
kubectl delete namespace ingress-nginx
```

**Files to Update in SIGHUP Distribution:**

- `templates/distribution/manifests/ingress/` - Add Gateway API as alternative
- Update documentation with migration guide
- Keep NGINX as option with deprecation notice

### 2. AppArmor Removal Coming

**Impact: LOW** (Not removed in 1.35, but previously deprecated)

AppArmor support was deprecated in v1.34 and continues as deprecated in v1.35. Begin migration planning.

**Check AppArmor Usage:**

```bash
# Search for AppArmor annotations
kubectl get pods --all-namespaces -o json | jq '.items[] | select(.metadata.annotations."container.apparmor.security.beta.kubernetes.io/*" != null) | {namespace: .metadata.namespace, name: .metadata.name}'

# If nothing found, you're good
```

---

## New Features to Leverage

### 1. In-Place Pod Resource Updates (Stable)

**Feature: KEP #1287** - Adjust CPU/memory without Pod restart

```yaml
# Before v1.35: Had to delete and recreate Pod to change resources
# After v1.35: Can update in-place

apiVersion: v1
kind: Pod
metadata:
  name: my-pod
spec:
  containers:
  - name: app
    image: myapp:latest
    resources:
      requests:
        memory: "128Mi"
        cpu: "100m"
      limits:
        memory: "512Mi"
        cpu: "500m"

# Now can be updated with:
# kubectl patch pod my-pod -p '{"spec":{"containers":[{"name":"app","resources":{"requests":{"cpu":"200m"}}}]}}'
```

**Benefits:**
- Vertical scaling without downtime
- No pod recreation required
- Great for stateful workloads

### 2. Pod Generation Tracking (Stable)

**Feature: KEP #4863** - Track spec changes

```yaml
# Pods now have generation fields for change tracking
apiVersion: v1
kind: Pod
metadata:
  generation: 2  # Incremented on spec change
status:
  observedGeneration: 2  # Kubelet's view of generation
```

### 3. User Namespaces (Beta)

**Feature: KEP #127** - Container user isolation

```yaml
# Pods run as root internally, mapped to unprivileged user on host
apiVersion: v1
kind: Pod
metadata:
  name: isolated-pod
spec:
  hostUsers: false  # Enable user namespace isolation
  containers:
  - name: app
    image: myapp:latest
    securityContext:
      runAsUser: 0  # Root in container, mapped to unprivileged on host
```

### 4. Image Volumes (Beta)

**Feature: KEP #4639** - OCI artifacts as volumes

```yaml
# Pull and unpack container images as volumes
apiVersion: v1
kind: Pod
metadata:
  name: image-volume-pod
spec:
  containers:
  - name: app
    image: myapp:latest
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    image:
      reference: myregistry.azurecr.io/data:v1.0  # OCI image as volume
```

### 5. Gang Scheduling (Alpha)

**Feature: KEP #4671** - All-or-nothing Pod placement

```yaml
# Useful for distributed training, HPC workloads
apiVersion: scheduling.k8s.io/v1alpha1
kind: PodGroup
metadata:
  name: training-group
spec:
  minMember: 4
  scheduleTimeoutSeconds: 3600
---
# All 4 pods must be schedulable together, or none schedule
```

---

## Version-Specific Updates Required

### Module Component Compatibility Matrix

Review and validate compatibility of all module components with Kubernetes 1.35:

| Module | Current Version | Status | Action Required |
|--------|-----------------|--------|-----------------|
| NGINX Ingress Controller | v4.1.1 | ⚠️ Deprecated | Plan Gateway API migration |
| Cert-Manager | Latest | ✅ Compatible | No immediate action |
| PrometheusOperator | v4.0.1 | ⚠️ Check | Validate CRD versions for 1.35 |
| LoggingOperator | v5.2.0 | ⚠️ Check | Test with containerd 2.0 |
| Gatekeeper/Kyverno | v1.15.0 | ⚠️ Check | Validate policy CRDs |
| Velero | v3.2.0 | ⚠️ Check | Test backup/restore with 1.35 |
| Calico/Cilium CNI | Latest | ⚠️ Check | Verify cgroup v2 compatibility |
| AWS Load Balancer Controller | v5.1.0 | ⚠️ Check | Test with 1.35 APIs |
| kube-proxy | - | 🔴 Critical | Migrate from IPVS to nftables |
| containerd | 1.7 LTS | 🔴 Critical | Upgrade to 2.0+ before v1.36 |

**Action:** Verify each operator explicitly supports Kubernetes 1.35 and cgroup v2.

### CRD and API Version Updates

**CRDs to Review:**
- `KFDDistribution` (v1alpha2)
- `EKSCluster` (v1alpha2)
- `OnPremises` (v1alpha2)

**Required Actions:**
- Validate all CRD schemas work with Kubernetes 1.35 API server
- Test custom resources in 1.35 test cluster
- Review for any deprecated API usage
- Validate policy controllers work with new RBAC model

---

## Specific Implementation Changes

### 1. Update kube-proxy Configuration (CRITICAL)

**Priority: CRITICAL - Required for production compatibility**

```yaml
# File: templates/distribution/manifests/networking/kube-proxy/configmap.yaml

apiVersion: v1
kind: ConfigMap
metadata:
  name: kube-proxy-config
  namespace: kube-system
data:
  kubeconfig.conf: |
    # ... kubeconfig content ...
  config.conf: |
    apiVersion: kubeproxy.config.k8s.io/v1alpha1
    kind: KubeProxyConfiguration
    # Before (DEPRECATED in 1.35)
    # mode: "ipvs"

    # After (RECOMMENDED for 1.35+)
    mode: "nftables"

    # Other settings
    hostnameOverride: ""
    clientConnection:
      kubeconfig: /var/lib/kube-proxy/kubeconfig.conf
    clusterCIDR: "10.0.0.0/8"
```

### 2. Update Kubelet Cgroup Configuration

**Files to Update:**

```bash
# On-premises installer
templates/distribution/terraform/onpremises/kubelet-config.yaml

# EKS
templates/distribution/terraform/eks/launch-template-user-data.sh
```

**Key Changes:**

```yaml
# Ensure cgroup v2 detection is enabled (default)
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
cgroupDriver: systemd
cgroupVersion: v2  # Explicit, though auto-detection works

# For on-premises, ensure systemd cgroup driver
systemCgroups: false
kubeReservedCgroups: ""
systemReservedCgroups: ""
```

### 3. Update Ingress Architecture (Prepare for Migration)

**Create Gateway API templates alongside NGINX:**

```bash
# New directory for Gateway API
mkdir -p templates/distribution/manifests/gateway-api

# Keep NGINX with deprecation notice
templates/distribution/manifests/ingress/  (mark as deprecated)

# Add Gateway API alternatives
templates/distribution/manifests/gateway-api/contour/
templates/distribution/manifests/gateway-api/cilium/
# etc.
```

### 4. Update Installation Tools Version (mise.toml)

```toml
# tools/kubectl
[tools.kubectl]
version = "1.35.x"  # Update to 1.35

# tools/containerd
[tools.containerd]
version = "2.0.0"  # Upgrade to 2.0+

# Other tools
[tools.kustomize]
version = "5.6.0"  # Verify compatibility

[tools.helm]
version = "3.12.3"  # Verify compatibility
```

### 5. Update RBAC Policies

**Search and Update All Pod Exec Rules:**

```bash
# Find all ClusterRoles with pod/exec permissions
grep -r "pods/exec" templates/distribution/

# Update each file:
# Before:
# - apiGroups: [""]
#   resources: ["pods/exec"]
#   verbs: ["get"]

# After:
# - apiGroups: [""]
#   resources: ["pods/exec", "pods/attach", "pods/portforward"]
#   verbs: ["create"]
```

**Files to Update:**

- `templates/distribution/manifests/auth/*/rbac.yaml`
- `templates/distribution/manifests/*/rbac.yaml` (any custom RBAC)

### 6. Update CI/CD Testing (.drone.yml)

Add Kubernetes 1.35 testing with cgroup v2 focus:

```yaml
# Add new test variants
- name: e2e-1.35-eks
  image: drone/drone-runner-docker:latest
  environment:
    KUBERNETES_VERSION: "1.35.0"
    CGROUP_VERSION: "v2"
    CONTAINERD_VERSION: "2.0.0"
    CLUSTER_TYPE: "eks"
  commands:
    - ./scripts/test-cgroup-v2-compatibility.sh
    - ./scripts/e2e-test.sh

- name: e2e-1.35-kfddistribution
  image: drone/drone-runner-docker:latest
  environment:
    KUBERNETES_VERSION: "1.35.0"
    CGROUP_VERSION: "v2"
    CLUSTER_TYPE: "kfddistribution"
  commands:
    - ./scripts/test-cgroup-v2-compatibility.sh
    - ./scripts/e2e-test.sh
```

### 7. Update Version Mappings (kfd.yaml)

```yaml
kubernetesVersions:
  - kubernetesVersion: "1.35"
    distributionVersion: "1.35.0"
    supported: true
    requirements:
      cgroupVersion: "v2"
      containerdVersion: "2.0.0+"
      kubeProxyMode: "nftables"
    modules:
      ingress:
        version: "v4.1.1"
        notes: "NGINX deprecated, Gateway API recommended"
      networking:
        version: "v3.0.0"
      # ... other modules
```

### 8. Create Testing Scripts

**Create test for cgroup v2 support:**

```bash
#!/bin/bash
# scripts/test-cgroup-v2-compatibility.sh

echo "Testing cgroup v2 compatibility..."

# Check kubelet cgroup version detection
kubectl get nodes -o jsonpath='{.items[*].status.nodeInfo}' | jq '.cgroupVersion'

# Verify all nodes report v2
for node in $(kubectl get nodes -o jsonpath='{.items[*].metadata.name}'); do
  cgroup_version=$(kubectl get node $node -o jsonpath='{.status.nodeInfo.cgroupVersion}')
  if [ "$cgroup_version" != "v2" ]; then
    echo "ERROR: Node $node is using cgroup $cgroup_version"
    exit 1
  fi
done

echo "✅ All nodes using cgroup v2"

# Test Pod resource updates (new feature)
kubectl run test-pod --image=nginx:latest --overrides='
{
  "spec": {
    "containers": [{
      "name": "test",
      "image": "nginx:latest",
      "resources": {
        "requests": {"memory": "64Mi", "cpu": "100m"},
        "limits": {"memory": "128Mi", "cpu": "200m"}
      }
    }]
  }
}'

# Update resources in-place
kubectl set resources pod test-pod --requests=memory=128Mi --limits=memory=256Mi

# Verify no restart
if kubectl logs test-pod 2>/dev/null; then
  echo "✅ Pod remained running during resource update"
fi

kubectl delete pod test-pod
```

### 9. Update Documentation

**Create files:**

1. **UPGRADE-1.35-MIGRATION-GUIDE.md** - Step-by-step for customers
2. **Update README.md** with 1.35 support
3. **Update MAINTENANCE.md** with timeline
4. **docs/gateway-api-migration.md** - NGINX → Gateway API guide
5. **docs/cgroup-v2-setup.md** - Detailed cgroup v2 setup guide

---

## Pre-Upgrade Checklist

### 🔴 CRITICAL BLOCKERS

- [ ] **Cgroup v2:** All nodes verified to support cgroup v2 (`stat -fc %T /sys/fs/cgroup/` returns `cgroup2fs`)
- [ ] **Cgroup v2:** All nodes upgraded to cgroup v2 before any control plane upgrade
- [ ] **Containerd Version:** containerd version 1.7+ verified on all nodes (plan upgrade to 2.0+)
- [ ] **Image Registry Audit:** No Docker Schema v1 images in use (for containerd 2.0)
- [ ] **Image Pull Secrets:** All registry credentials validated and non-expired
- [ ] **IPVS Migration:** Plan created for IPVS → nftables migration if using IPVS mode

### 🟠 HIGH PRIORITY

- [ ] **RBAC Audit:** All pod/exec, pod/attach, pod/portforward rules updated to require `create` verb
- [ ] **Module Versions:** Verified all operators support Kubernetes 1.35
  - [ ] NGINX Ingress Controller (plan Gateway API migration)
  - [ ] PrometheusOperator
  - [ ] LoggingOperator
  - [ ] Gatekeeper/Kyverno
  - [ ] Velero
  - [ ] CNI (Calico/Cilium)
  - [ ] AWS Load Balancer Controller
- [ ] **CRD Schemas:** All custom resource schemas validated against 1.35
- [ ] **Kustomize Patches:** All patch strategies tested with 1.35 schema
- [ ] **CI/CD Tests:** 1.35 test suite added and passing

### 🟡 MEDIUM PRIORITY

- [ ] **Tool Versions:** Updated mise.toml with 1.35-compatible tool versions
- [ ] **containerd 2.0 Plan:** Migration path documented and tested
- [ ] **Gateway API Research:** Evaluated Gateway API controllers (Contour, Cilium, etc.)
- [ ] **Staging Deployment:** Full distribution deployed on 1.35 with cgroup v2
- [ ] **Disaster Recovery:** Velero tested with 1.35 and containerd 2.0
- [ ] **Network Policies:** All network policies validated with 1.35

### 🟢 LOW PRIORITY

- [ ] **Feature Leverage:** Evaluated new 1.35 features (in-place pod resize, user namespaces, etc.)
- [ ] **Documentation:** Updated README, MAINTENANCE.md, ROADMAP.md
- [ ] **Release Notes:** Draft release notes prepared
- [ ] **Performance Baseline:** Established metrics before upgrade

---

## Recommended Upgrade Path

### Phase 1: Infrastructure Preparation (3-4 weeks)

**Goal:** Ensure all prerequisites are met before ANY Kubernetes upgrade

1. **Cgroup v2 Upgrade** (Week 1-2)
   - Identify all nodes running cgroup v1
   - Plan maintenance window
   - Upgrade OS on each node (or rebuild with newer OS)
   - Verify all nodes report cgroup v2
   - **BLOCKER:** Cannot proceed without this

2. **Containerd 2.0 Migration** (Week 2-3)
   - Audit images in registries
   - Test containerd 2.0 on non-production cluster
   - Plan per-node upgrade strategy
   - Prepare rollback plan
   - **Note:** Can do this while on Kubernetes 1.34

3. **kube-proxy IPVS → nftables** (Week 3)
   - Test nftables mode in staging
   - If using IPVS, plan cutover
   - Update configuration

4. **Image Pull Secret Validation** (Week 1)
   - Audit all pull secrets
   - Rotate expiring credentials
   - Test credential refresh process

### Phase 2: Development and Testing (2-3 weeks)

1. **Feature Branch Creation**
   - Create: `upgrade/kubernetes-1.35`
   - Branch from: `release/v1.34.x`

2. **Update Manifests**
   - Update image references (if needed for registry paths)
   - Update kube-proxy configuration
   - Update RBAC policies for pod/exec
   - Update tool versions

3. **Staging Deployment**
   - Deploy to Kubernetes 1.35 staging cluster with cgroup v2
   - Verify all modules work
   - Test new features (in-place pod resize, etc.)
   - Performance testing

4. **Integration Testing**
   - Full e2e test suite with 1.35
   - Test upgrade path 1.34 → 1.35
   - Test containerd 2.0 with all modules
   - Disaster recovery testing

### Phase 3: Documentation and Release (1-2 weeks)

1. **Documentation**
   - Complete UPGRADE-1.35.md
   - Create customer migration guide
   - Update release notes
   - Document known issues

2. **Final Validation**
   - Security audit of 1.35 changes
   - Compliance check (cgroup v2, RBAC changes)
   - Performance baseline comparison

3. **Stakeholder Review**
   - Internal team sign-off
   - Security team review
   - Customer advisory (if applicable)

### Phase 4: Release (1 week)

1. **Merge and Release**
   - Merge feature branch to main
   - Create release branch: `release/v1.35.0`
   - Tag: `v1.35.0`
   - Build artifacts

2. **Communication**
   - Publish release notes
   - Announce upgrade availability
   - Provide migration guidance

### Phase 5: Customer Rollout (Ongoing)

1. **Phased Rollout**
   - Early adopter enrollment
   - Monitor for issues
   - Patch releases (v1.35.1, etc.) as needed

2. **Support Period**
   - Maintain v1.34.x for 6+ months
   - Support v1.35.x as current
   - Plan v1.36 in Q4 2026

---

## Testing Strategy

### Pre-Upgrade Validation

```bash
# Comprehensive pre-flight checks
scripts/pre-upgrade-1.35-validation.sh
  ├─ Verify cgroup v2 on all nodes
  ├─ Check containerd version (1.7+)
  ├─ Validate image pull secrets
  ├─ Audit RBAC pod/exec permissions
  ├─ Check for IPVS mode usage
  └─ Verify all operator versions
```

### Unit Tests

```bash
go test ./pkg/...
go test ./...
```

### Integration Tests

```bash
# Create kind cluster with cgroup v2
kind create cluster --image kindest/node:v1.35.0-rc.0

# Deploy SIGHUP Distribution
./scripts/deploy-distribution.sh

# Run module tests
./scripts/test-modules.sh
```

### E2E Testing Matrix

- [ ] EKS v1.35 with cgroup v2, containerd 2.0
- [ ] KFDDistribution (self-managed) v1.35, cgroup v2, containerd 2.0
- [ ] On-premises bare-metal v1.35, cgroup v2
- [ ] Each module individually
- [ ] All modules together
- [ ] Upgrade from 1.34 → 1.35
- [ ] In-place pod resource updates
- [ ] nftables mode kube-proxy
- [ ] New RBAC model for pod/exec
- [ ] Gateway API (if implemented)

### Performance Testing

```bash
# Establish baseline
./scripts/perf-baseline.sh

# After upgrade
./scripts/perf-test-1.35.sh

# Compare metrics
./scripts/compare-perf-results.sh
```

---

## Rollback Plan

In case of critical issues:

1. **Immediate Rollback**
   - Keep v1.34.x branch updated
   - Test rollback procedure in staging
   - Document rollback steps

2. **Graceful Degradation**
   - Run mixed v1.34/v1.35 control planes (short-term)
   - Drain 1.35 nodes, upgrade kubelet back to 1.34
   - Restore from backup if needed

3. **Restore from Backup**
   - Velero backups from v1.34 available
   - Database backups of cluster state
   - Test restore procedure beforehand

---

## Known Issues and Workarounds

(To be populated during testing phase)

| Issue | Workaround | Status | Component |
|-------|-----------|--------|-----------|
| Example | Example | Under Investigation | Module |

---

## Important References

### Official Kubernetes Resources
- [Kubernetes v1.35 Release: Timbernetes](https://kubernetes.io/blog/2025/12/17/kubernetes-v1-35-release/)
- [Kubernetes 1.35 Changelog](https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG/CHANGELOG-1.35.md)
- [Kubernetes Cgroup v2 Documentation](https://kubernetes.io/docs/concepts/architecture/cgroups/)
- [Kubernetes Version Skew Policy](https://kubernetes.io/docs/setup/release/version-skew-policy/)

### Breaking Changes and Migration Guides
- [ScaleOps: Kubernetes 1.35 Upgrade Guide](https://scaleops.com/blog/kubernetes-1-35-release-overview/)
- [Sysdig: Kubernetes 1.35 Security Features](https://www.sysdig.com/blog/kubernetes-1-35-whats-new)
- [MetalBear: Kubernetes 1.35 Features](https://metalbear.com/blog/kubernetes-1-35/)
- [Kubernetes 1.35 vs 1.34 Analysis](https://user-cube.medium.com/kubernetes-v1-35-timbernetes-whats-new-and-what-s-changing-654817df7e95)

### Container Runtime Documentation
- [containerd 2.0 Migration Guide](https://github.com/containerd/containerd/blob/main/RELEASES.md)
- [Cgroup v2 Setup Guide](https://docs.kernel.org/admin-guide/cgroup-v2.html)
- [nftables vs iptables Guide](https://wiki.nftables.org/)

### Gateway API Migration
- [Kubernetes Gateway API](https://gateway-api.sigs.k8s.io/)
- [ingress2gateway Tool](https://github.com/kubernetes-sigs/ingress2gateway)
- [Contour Gateway API](https://projectcontour.io/)

---

## Timeline Summary

| Phase | Duration | Deliverables |
|-------|----------|--------------|
| Infrastructure Prep | 3-4 weeks | Cgroup v2 upgrade, containerd 2.0 ready |
| Development & Testing | 2-3 weeks | Updated manifests, passing tests |
| Documentation | 1-2 weeks | Release notes, migration guides |
| Release | 1 week | v1.35.0 tagged and published |
| Customer Rollout | Ongoing | Support and patch releases |

---

## Contact and Support

For questions about the Kubernetes 1.35 upgrade:

1. Review this guide's [Known Issues](#known-issues-and-workarounds) section
2. Check official Kubernetes v1.35 documentation
3. Review module-specific upgrade guides
4. Contact SIGHUP team for enterprise support

---

**Last Updated:** 2026-01-09
**Target Release:** SD v1.35.0
**Kubernetes Version:** 1.35.0+
**Status:** Pre-release planning
**Next Review:** 2026-02-01
