#!/usr/bin/env bash
# Remove all bridges and namespaces created by the labs.
for n in ns1 ns2 ns3 ns4 hostA hostB h1 h2; do ip netns del $n 2>/dev/null || true; done
ovs-vsctl --if-exists del-br ovsbr0
ovs-vsctl --if-exists del-br ovsbr1
ovs-vsctl --if-exists del-br br-of
echo "Cleaned up bridges and namespaces."
