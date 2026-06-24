#!/usr/bin/env bash
# Lab 4 — OpenFlow programming. Bridge in secure mode forwards ONLY via
# hand-written flows; a higher-priority rule acts as an ICMP firewall.
set -e

ovs-vsctl --if-exists del-br br-of
ovs-vsctl add-br br-of
ovs-vsctl set-fail-mode br-of secure      # no automatic NORMAL forwarding

for n in h1 h2; do ip netns del $n 2>/dev/null || true; ip netns add $n; done
ip link add p1 type veth peer name ovs-p1
ip link add p2 type veth peer name ovs-p2
ip link set p1 netns h1; ip link set p2 netns h2
ovs-vsctl add-port br-of ovs-p1
ovs-vsctl add-port br-of ovs-p2
ip link set ovs-p1 up; ip link set ovs-p2 up
ip netns exec h1 ip addr add 10.1.1.1/24 dev p1; ip netns exec h1 ip link set p1 up
ip netns exec h2 ip addr add 10.1.1.2/24 dev p2; ip netns exec h2 ip link set p2 up
P1=$(ovs-vsctl get interface ovs-p1 ofport); P2=$(ovs-vsctl get interface ovs-p2 ofport)

echo "== No flows yet: expect BLOCKED =="
ip netns exec h1 ping -c2 -W1 10.1.1.2 >/dev/null 2>&1 && echo "reachable" || echo "BLOCKED (no flows)"

echo "== Add forwarding flows at priority=10 =="
ovs-ofctl add-flow br-of "priority=10,in_port=$P1,actions=output:$P2"
ovs-ofctl add-flow br-of "priority=10,in_port=$P2,actions=output:$P1"
ip netns exec h1 ping -c2 -W1 10.1.1.2 | grep "packet loss"

echo "== Add firewall: drop ICMP at priority=100 (must exceed forwarding priority!) =="
ovs-ofctl add-flow br-of "priority=100,icmp,actions=drop"
ip netns exec h1 ping -c2 -W1 10.1.1.2 >/dev/null 2>&1 && echo "reachable" || echo "ICMP BLOCKED by OpenFlow (correct)"

echo "== Flow table with hit counters =="
ovs-ofctl dump-flows br-of
