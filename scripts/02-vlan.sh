#!/usr/bin/env bash
# Lab 2 — VLAN segmentation. Requires Lab 1 topology (ovsbr0 with ns1, ns2).
# Adds ns3, ns4 and splits hosts into VLAN 100 and VLAN 200.
set -e

for n in ns3 ns4; do ip netns del $n 2>/dev/null || true; ip netns add $n; done
ip link add veth3 type veth peer name ovs-veth3
ip link add veth4 type veth peer name ovs-veth4
ip link set veth3 netns ns3
ip link set veth4 netns ns4
ovs-vsctl add-port ovsbr0 ovs-veth3
ovs-vsctl add-port ovsbr0 ovs-veth4
ip link set ovs-veth3 up
ip link set ovs-veth4 up
ip netns exec ns3 ip addr add 10.0.0.3/24 dev veth3; ip netns exec ns3 ip link set veth3 up
ip netns exec ns4 ip addr add 10.0.0.4/24 dev veth4; ip netns exec ns4 ip link set veth4 up

# ns1,ns3 -> VLAN 100   ns2,ns4 -> VLAN 200
ovs-vsctl set port ovs-veth1 tag=100
ovs-vsctl set port ovs-veth3 tag=100
ovs-vsctl set port ovs-veth2 tag=200
ovs-vsctl set port ovs-veth4 tag=200

echo "== ns1 -> ns3 (same VLAN 100): expect SUCCESS =="
ip netns exec ns1 ping -c2 -W1 10.0.0.3 && echo "OK reachable" || echo "blocked"
echo "== ns1 -> ns2 (VLAN 100 vs 200, same subnet): expect BLOCKED =="
ip netns exec ns1 ping -c2 -W1 10.0.0.2 && echo "reachable" || echo "BLOCKED by VLAN (correct)"
echo "== ns2 -> ns4 (same VLAN 200): expect SUCCESS =="
ip netns exec ns2 ping -c2 -W1 10.0.0.4 && echo "OK reachable" || echo "blocked"
