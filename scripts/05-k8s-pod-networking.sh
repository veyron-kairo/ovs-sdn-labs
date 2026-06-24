#!/usr/bin/env bash
# Lab 5 — Kubernetes pod networking with a CNI.
# Requires a running k3s cluster:  curl -sfL https://get.k3s.io | sh -
# Shows pod-to-pod connectivity, the CNI bridge + VXLAN backend, and a Service.
set -e
K="k3s kubectl"   # run this script with sudo, or as a user with kubeconfig

echo "== Deploy 2 web pods + 1 client pod =="
$K create deployment web --image=nginx --replicas=2 2>/dev/null || true
$K run client --image=busybox --restart=Never --command -- sleep 3600 2>/dev/null || true
$K wait --for=condition=Ready pod -l app=web --timeout=120s
$K wait --for=condition=Ready pod/client --timeout=120s

echo "== Pods and their IPs =="
$K get pods -o wide

echo "== Pod-to-pod networking: client curls each web pod by IP =="
for ip in $($K get pods -l app=web -o jsonpath='{.items[*].status.podIP}'); do
  echo -n "client -> $ip : "
  $K exec client -- wget -qO- --timeout=5 http://$ip >/dev/null 2>&1 && echo "OK" || echo "FAILED"
done

echo "== The CNI (Flannel) built a bridge (cni0) + a VXLAN device (flannel.1) =="
ip -br addr show | grep -E "cni0|flannel"
ip -d link show flannel.1 | grep -i vxlan

echo "== Expose pods behind a Service (ClusterIP load-balancing) =="
$K expose deployment web --port=80 2>/dev/null || true
$K get svc web
SVC=$($K get svc web -o jsonpath='{.spec.clusterIP}')
for i in 1 2 3; do
  $K exec client -- wget -qO- --timeout=5 http://$SVC >/dev/null 2>&1 && echo "request $i -> $SVC : OK" || echo "request $i : FAILED"
done
