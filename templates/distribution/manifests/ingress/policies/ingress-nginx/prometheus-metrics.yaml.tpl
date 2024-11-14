# Copyright (c) 2017-present SIGHUP s.r.l All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: nginx-ingress-prometheus-metrics
  namespace: ingress-nginx
  labels:
    cluster.kfd.sighup.io/module: ingress
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
    - Ingress
  ingress:
    - from:
      - namespaceSelector:
          matchLabels:
            kubernetes.io/metadata.name: monitoring
        podSelector:
          matchLabels:
            app.kubernetes.io/name: prometheus
      ports:
        - protocol: TCP
          port: 10254
