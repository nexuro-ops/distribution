# Copyright (c) 2017-present SIGHUP s.r.l All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

# source: https://github.com/prometheus-operator/kube-prometheus/blob/main/manifests/prometheus-networkPolicy.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: prometheus-k8s
  namespace: monitoring
spec:
  egress:
  - {}
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app.kubernetes.io/name: prometheus
    ports:
    - port: 9090
      protocol: TCP
    - port: 8080
      protocol: TCP
  - from:
    - podSelector:
        matchLabels:
          app.kubernetes.io/name: prometheus-adapter
    ports:
    - port: 9090
      protocol: TCP
  - from:
    - podSelector:
        matchLabels:
          app.kubernetes.io/name: grafana
    ports:
    - port: 9090
      protocol: TCP
  podSelector:
    matchLabels:
      app.kubernetes.io/component: prometheus
      app.kubernetes.io/instance: k8s
      app.kubernetes.io/name: prometheus
      app.kubernetes.io/part-of: kube-prometheus
  policyTypes:
  - Egress
  - Ingress
