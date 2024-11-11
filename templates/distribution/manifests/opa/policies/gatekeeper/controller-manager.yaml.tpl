# Copyright (c) 2017-present SIGHUP s.r.l All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: controllermanager-egress-kubeapiserver
  namespace: gatekeeper-system
spec:
  podSelector:
    matchLabels:
      control-plane: controller-manager
  policyTypes:
    - Egress
  egress:
  - ports:
    - port: 6443
      protocol: TCP
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: controllermanager-ingress-kubeapiserver
  namespace: gatekeeper-system
spec:
  podSelector:
    matchLabels:
      control-plane: controller-manager
  policyTypes:
    - Ingress
  ingress:
    - ports:
        - protocol: TCP
          port: 8443
        - protocol: TCP
          port: 443 
