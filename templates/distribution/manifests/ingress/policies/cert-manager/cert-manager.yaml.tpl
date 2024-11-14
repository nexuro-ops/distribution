# Copyright (c) 2017-present SIGHUP s.r.l All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

# https://cert-manager.io/docs/installation/best-practice/#network-requirements
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: cert-manager-egress-kube-apiserver
  namespace: cert-manager
  labels:
    cluster.kfd.sighup.io/ingress-type: nginx
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/instance: cert-manager
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
  name: cert-manager-webhook-ingress-kube-apiserver
  namespace: cert-manager
  labels:
    cluster.kfd.sighup.io/ingress-type: nginx
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/component: webhook
      app.kubernetes.io/instance: cert-manager
  policyTypes:
    - Ingress
  ingress:
    - ports:
      - port: 10250
        protocol: TCP
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: cert-manager-egress-https
  namespace: cert-manager
  labels:
    cluster.kfd.sighup.io/ingress-type: nginx
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/component: controller
      app.kubernetes.io/instance: cert-manager
  policyTypes:
    - Egress
  egress:
    - ports:
      - port: 443
        protocol: TCP
      - port: 80
        protocol: TCP
---
{{- if eq .spec.distribution.modules.auth.provider.type "sso" }}
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: acme-http-solver-ingress-lets-encrypt
  namespace: pomerium
  labels:
    cluster.kfd.sighup.io/ingress-type: nginx
spec:
  podSelector:
    matchLabels:
      app: cert-manager
  policyTypes:
    - Ingress
  ingress:
    - ports:
        - port: 8089
          protocol: TCP
---
{{- end }}
