#!/usr/bin/env bash
# Lab 1 — L2 software switch with Open vSwitch.
# Two isolated hosts (network namespaces) talk across one OVS bridge.
set -e

ovs-vsctl --if-exists del-br ovsbr0
ovs-vsctl add-br ovsbr0

for n in ns1 ns2; do ip netns del $n 2>/dev/null || true; ip netns add $n; done

ip link add veth1 type veth peer name ovs-veth1
ip link add veth2 type veth peer name ovs-veth2
ip link set veth1 netns ns1
ip link set veth2 netns ns2
ovs-vsctl add-port ovsbr0 ovs-veth1
ovs-vsctl add-port ovsbr0 ovs-veth2
ip link set ovs-veth1 up
ip link set ovs-veth2 up

ip netns exec ns1 ip addr add 10.0.0.1/24 dev veth1; ip netns exec ns1 ip link set veth1 up; ip netns exec ns1 ip link set lo up
ip netns exec ns2 ip addr add 10.0.0.2/24 dev veth2; ip netns exec ns2 ip link set veth2 up; ip netns exec ns2 ip link set lo up

echo "== ns1 pings ns2 across the OVS bridge =="
ip netns exec ns1 ping -c 4 10.0.0.2

echo "== Flow table (packets forwarded) =="
ovs-ofctl dump-flows ovsbr0
echo "== MAC learning table =="
ovs-appctl fdb/show ovsbr0
