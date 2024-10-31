# Copyright (c) 2017-present SIGHUP s.r.l All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: opensearch-dashboards-egress-opensearch
  namespace: logging
  labels:
    app: opensearch-dashboards
spec:
  policyTypes:
    - Egress
  podSelector:
    matchLabels:
      app: opensearch-dashboards
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: logging
          podSelector:
            matchLabels:
              app.kubernetes.io/name: opensearch
      ports:
        - port: 9200
          protocol: TCP
          