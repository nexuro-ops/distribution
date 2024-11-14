# Copyright (c) 2017-present SIGHUP s.r.l All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: acme-httpsolver-ingress-nginx
  namespace: pomerium
  labels:
    cluster.kfd.sighup.io/auth-provider-type: sso
spec:
  podSelector:
    matchLabels:
      app: cert-manager
  policyTypes:
    - Ingress
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
        - port: 8089
          protocol: TCP
---
