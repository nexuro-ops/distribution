# Copyright (c) 2017-present SIGHUP s.r.l All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: pomerium-ingress-nginx
  namespace: pomerium
  labels:
    cluster.kfd.sighup.io/module: auth
    cluster.kfd.sighup.io/auth-provider-type: sso
spec:
  policyTypes:
    - Ingress
  podSelector:
    matchLabels:
      app: pomerium
  ingress:
    - from:
      - namespaceSelector:
          matchLabels:
            kubernetes.io/metadata.name: ingress-nginx
        podSelector:
          matchLabels:
{{- if eq .spec.distribution.modules.ingress.nginx.type "dual" }}
            app: ingress
{{- else if eq .spec.distribution.modules.ingress.nginx.type "single" }}
            app: ingress-nginx
{{- end }}
      ports:
        - port: 8080
          protocol: TCP
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: pomerium-egress-all
  namespace: pomerium
  labels:
    cluster.kfd.sighup.io/module: auth
    cluster.kfd.sighup.io/auth-provider-type: sso
spec:
 policyTypes:
   - Egress
 podSelector:
   matchLabels:
     app: pomerium
 egress:
  - {}
---
