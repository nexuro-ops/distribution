# Copyright (c) 2017-present SIGHUP s.r.l All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: nginx-egress-all
  namespace: ingress-nginx
  labels:
    cluster.kfd.sighup.io/ingress-type: nginx
spec:
  podSelector:
    matchLabels:
{{- if eq .spec.distribution.modules.ingress.nginx.type "dual" }}
      app: ingress
{{- else if eq .spec.distribution.modules.ingress.nginx.type "single" }}
      app: ingress-nginx
{{- end }}
  policyTypes:
  - Egress
  egress:
  - {}
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: all-ingress-nginx
  namespace: ingress-nginx
  labels:
    cluster.kfd.sighup.io/ingress-type: nginx
spec:
  podSelector:
    matchLabels:
{{- if eq .spec.distribution.modules.ingress.nginx.type "dual" }}
      app: ingress
{{- else if eq .spec.distribution.modules.ingress.nginx.type "single" }}
      app: ingress-nginx
{{- end }}
  ingress:
    - ports:
      - port: 8080
        protocol: TCP
      - port: 8443
        protocol: TCP
      - port: 9443
        protocol: TCP
  policyTypes:
  - Ingress
