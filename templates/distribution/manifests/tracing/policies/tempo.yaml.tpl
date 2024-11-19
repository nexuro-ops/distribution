apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: tempo-distributed-discovery
  namespace: tracing
  labels:
    cluster.kfd.sighup.io/module: tracing
spec:
  policyTypes:
    - Ingress
    - Egress
  podSelector:
    matchLabels:
      app.kubernetes.io/name: tempo
  ingress:
    - ports:
        - port: 9095
          protocol: TCP
        - port: 7946
          protocol: TCP
        - port: 3100
          protocol: TCP
      from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: tracing
          podSelector:
            matchLabels:
              app.kubernetes.io/name: tempo
  egress:
    - ports:
        - port: 9095
          protocol: TCP
        - port: 7946
          protocol: TCP
        - port: 3100
          protocol: TCP
      to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: tracing
          podSelector:
            matchLabels:
              app.kubernetes.io/name: tempo
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: tempo-gateway-ingress-grafana
  namespace: tracing
  labels:
    cluster.kfd.sighup.io/module: tracing
spec:
  policyTypes:
    - Ingress
  podSelector:
    matchLabels:
      app.kubernetes.io/component: gateway
      app.kubernetes.io/name: tempo
      app.kubernetes.io/instance: tempo-distributed
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: monitoring
          podSelector:
            matchLabels:
              app.kubernetes.io/component: grafana
              app.kubernetes.io/name: grafana
              app.kubernetes.io/part-of: kube-prometheus
      ports:
        - port: 8080
          protocol: TCP
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: all-egress-tempo-distributor
  namespace: tracing
  labels:
    cluster.kfd.sighup.io/module: tracing
spec:
  policyTypes:
    - Egress
  podSelector: {} 
  egress:
    - to:
        - podSelector:
            matchLabels:
              app.kubernetes.io/name: tempo
              app.kubernetes.io/component: distributor
      ports:
        - port: 4317
          protocol: TCP
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: tempo-distributor-ingress-traces
  namespace: tracing
  labels:
    cluster.kfd.sighup.io/module: tracing
spec:
  policyTypes:
    - Ingress
  podSelector:
    matchLabels:
      app.kubernetes.io/name: tempo
      app.kubernetes.io/component: distributor
  ingress:
    - ports:
        - port: 4317
          protocol: TCP
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: tempo-components-egress-memcached
  namespace: tracing
  labels:
    cluster.kfd.sighup.io/module: tracing
spec:
 policyTypes:
   - Egress
 podSelector:
   matchLabels:
     app.kubernetes.io/instance: tempo-distributed
 egress:
   - to:
       - podSelector:
           matchLabels:
             app.kubernetes.io/name: tempo
             app.kubernetes.io/component: memcached
     ports:
       - port: 11211
         protocol: TCP
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: memcached-ingress-querier
  namespace: tracing
  labels:
    cluster.kfd.sighup.io/module: tracing
spec:
  policyTypes:
    - Ingress
  podSelector:
    matchLabels:
      app.kubernetes.io/name: tempo
      app.kubernetes.io/component: memcached
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app.kubernetes.io/name: tempo
              app.kubernetes.io/component: querier
      ports:
        - port: 11211
          protocol: TCP
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: tempo-distributed-ingress-prometheus-metrics
  namespace: tracing
  labels:
    cluster.kfd.sighup.io/module: tracing
spec:
  policyTypes:
    - Ingress
  podSelector:
    matchLabels:
      app.kubernetes.io/name: tempo
  ingress:
    - ports:
        - port: 3100
          protocol: TCP
      from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: monitoring
          podSelector:
            matchLabels:
              app.kubernetes.io/name: prometheus
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: tempo-components-egress-https
  namespace: tracing
  labels:
    cluster.kfd.sighup.io/module: tracing
spec:
 policyTypes:
   - Egress
 podSelector:
   matchLabels:
     app.kubernetes.io/name: tempo
     app.kubernetes.io/instance: tempo-distributed
 egress:
   - ports:
       - port: 443
         protocol: TCP
{{- if eq .spec.distribution.modules.tracing.tempo.backend "minio" }}
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: tempo-distributed-egress-minio
  namespace: tracing
  labels:
    cluster.kfd.sighup.io/module: tracing
    cluster.kfd.sighup.io/tracing-backend: minio
spec:
  policyTypes:
    - Egress
  podSelector:
    matchLabels:
      app.kubernetes.io/name: tempo
  egress:
    - to:
        - podSelector:
            matchLabels:
              app: minio
          namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: tracing
      ports:
          - port: 9000
            protocol: TCP
{{- else }}
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: tempo-distributed-egress-all
  namespace: tracing
  labels:
    cluster.kfd.sighup.io/module: tracing
spec:
  policyTypes:
    - Egress
  podSelector:
    matchLabels:
      app.kubernetes.io/name: tempo
  egress:
    - {}
{{- end }}
---
