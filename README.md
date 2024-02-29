## Istio & Prometheus Operator

Install Promethues as an operator in a mesh (istio) enabled K8s cluster

We configure `PodMonitor` for all istio enabled pods in the cluster and `ServiceMonitor` for Istio Pilot.