#!/usr/bin/env bash
# Lab 3 — VXLAN overlay tunnel between two simulated physical servers.
# Underlay 172.16.0.0/24 carries an overlay 192.168.99.0/24 (VNI 42).
set -e

for n in hostA hostB; do ip netns del $n 2>/dev/null || true; ip netns add $n; done
ip link add vethA type veth peer name vethB
ip link set vethA netns hostA
ip link set vethB netns hostB

# Underlay ("physical" link)
ip netns exec hostA ip addr add 172.16.0.1/24 dev vethA; ip netns exec hostA ip link set vethA up; ip netns exec hostA ip link set lo up
ip netns exec hostB ip addr add 172.16.0.2/24 dev vethB; ip netns exec hostB ip link set vethB up; ip netns exec hostB ip link set lo up
echo "== Underlay reachability =="
ip netns exec hostA ping -c1 -W1 172.16.0.2

# VXLAN tunnel
ip netns exec hostA ip link add vxlan42 type vxlan id 42 remote 172.16.0.2 local 172.16.0.1 dev vethA dstport 4789
ip netns exec hostA ip addr add 192.168.99.1/24 dev vxlan42; ip netns exec hostA ip link set vxlan42 up
ip netns exec hostB ip link add vxlan42 type vxlan id 42 remote 172.16.0.1 local 172.16.0.2 dev vethB dstport 4789
ip netns exec hostB ip addr add 192.168.99.2/24 dev vxlan42; ip netns exec hostB ip link set vxlan42 up

echo "== Capturing underlay while pinging overlay =="
ip netns exec hostB timeout 6 tcpdump -nn -i vethB udp port 4789 > /tmp/vxcap.txt 2>/dev/null &
sleep 1
ip netns exec hostA ping -c 3 192.168.99.2
wait
echo "== Underlay capture: overlay traffic is VXLAN-encapsulated (UDP/4789) =="
head -6 /tmp/vxcap.txt
