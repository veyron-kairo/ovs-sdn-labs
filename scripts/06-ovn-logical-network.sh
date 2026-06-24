#!/usr/bin/env bash
# Lab 6 - OVN (Open Virtual Network), the SDN system behind OVN-Kubernetes.
# Builds a logical switch, then two switches joined by a logical router, all
# defined in the OVN database and programmed into OVS automatically.
#
# Install first: sudo apt-get install -y ovn-central ovn-host ovn-common
set -e

echo "== Register this host as an OVN chassis =="
sudo ovs-vsctl set open . external-ids:system-id=chassis-1
sudo ovs-vsctl set open . external-ids:ovn-remote=unix:/var/run/ovn/ovnsb_db.sock
sudo ovs-vsctl set open . external-ids:ovn-encap-type=geneve
sudo ovs-vsctl set open . external-ids:ovn-encap-ip=127.0.0.1
sudo systemctl restart ovn-controller
sleep 2
sudo ovn-sbctl show   # chassis should appear; ovn-controller creates br-int

# helper: bind a logical port to a namespace
bind_port() {  # $1=netns $2=ovs-port $3=iface-id $4=mac $5=cidr
  sudo ip netns del "$1" 2>/dev/null || true; sudo ip netns add "$1"
  sudo ovs-vsctl add-port br-int "$2" -- set interface "$2" type=internal external-ids:iface-id="$3"
  sudo ip link set "$2" netns "$1"
  sudo ip netns exec "$1" ip link set "$2" address "$4"
  sudo ip netns exec "$1" ip addr add "$5" dev "$2"
  sudo ip netns exec "$1" ip link set "$2" up
  sudo ip netns exec "$1" ip link set lo up
}

echo "== Logical switch ls1 with two ports =="
sudo ovn-nbctl ls-add ls1
sudo ovn-nbctl lsp-add ls1 lp1
sudo ovn-nbctl lsp-set-addresses lp1 "40:00:00:00:00:01 192.168.10.1"
sudo ovn-nbctl lsp-add ls1 lp2
sudo ovn-nbctl lsp-set-addresses lp2 "40:00:00:00:00:02 192.168.10.2"
bind_port vm1 vm1p lp1 40:00:00:00:00:01 192.168.10.1/24
bind_port vm2 vm2p lp2 40:00:00:00:00:02 192.168.10.2/24

echo "== Logical router lr1 joining ls1 to a new subnet ls2 =="
sudo ovn-nbctl lr-add lr1
sudo ovn-nbctl lrp-add lr1 lrp-ls1 40:00:00:00:01:01 192.168.10.254/24
sudo ovn-nbctl lsp-add ls1 ls1-rp
sudo ovn-nbctl lsp-set-type ls1-rp router
sudo ovn-nbctl lsp-set-addresses ls1-rp router
sudo ovn-nbctl lsp-set-options ls1-rp router-port=lrp-ls1

sudo ovn-nbctl ls-add ls2
sudo ovn-nbctl lrp-add lr1 lrp-ls2 40:00:00:00:02:01 192.168.20.254/24
sudo ovn-nbctl lsp-add ls2 ls2-rp
sudo ovn-nbctl lsp-set-type ls2-rp router
sudo ovn-nbctl lsp-set-addresses ls2-rp router
sudo ovn-nbctl lsp-set-options ls2-rp router-port=lrp-ls2

sudo ovn-nbctl lsp-add ls2 lp3
sudo ovn-nbctl lsp-set-addresses lp3 "40:00:00:00:00:03 192.168.20.1"
bind_port vm3 vm3p lp3 40:00:00:00:00:03 192.168.20.1/24
sudo ip netns exec vm3 ip route add default via 192.168.20.254
sudo ip netns exec vm1 ip route add default via 192.168.10.254 2>/dev/null || true

sleep 3
echo "== Full logical topology =="
sudo ovn-nbctl show

echo "== Test 1: vm1 -> vm2 (same logical switch) =="
sudo ip netns exec vm1 ping -c 3 192.168.10.2
echo "== Test 2: vm1 -> vm3 (across the logical router, note ttl=63) =="
sudo ip netns exec vm1 ping -c 3 192.168.20.1
