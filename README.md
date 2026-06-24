# OVS SDN Labs — hands-on Software-Defined Networking with Open vSwitch

A set of self-built networking labs exploring **Open vSwitch (OVS)**, **VLANs**, **VXLAN overlays**, and **OpenFlow** programming on Linux — the foundations behind modern data-center networking and the [OPI](https://opiproject.org/) *DPU-Accelerated OVS Offload* work.

> Built from scratch on an Ubuntu VM (Apple M4 Mac → Lima) as preparation for the
> LFX Mentorship "DPU-Accelerated OVS Offload" under the OPI project.
> Every result below is real output captured from these scripts.

## Why this exists
The OVS datapath that these labs program in software is exactly what a **DPU**
(Data Processing Unit, e.g. NVIDIA BlueField) offloads into hardware — freeing the
host CPU and boosting throughput. To understand hardware offload, you first have to
understand the software path. These labs build that understanding from the ground up.

## Environment
- Ubuntu 26.04 LTS (aarch64) · Open vSwitch 3.7.1 · QEMU 10.2.1 · libvirt 12.0.0
- Hosts are simulated with Linux **network namespaces** wired to OVS via veth pairs.

---

## Lab 1 — L2 software switch (`scripts/01-l2-switch.sh`)
Two isolated hosts on one OVS bridge, exchanging real traffic; OVS learns their MACs.

```
ns1 (10.0.0.1) --veth--+
                       ovsbr0  (Open vSwitch)
ns2 (10.0.0.2) --veth--+
```
**Result:** `4 packets transmitted, 4 received, 0% packet loss`, flow table counter
rose to `n_packets=84`, and the MAC table learned both hosts.
**Skills:** OVS bridges/ports, OpenFlow `NORMAL` action, MAC learning, L2 forwarding.

---

## Lab 2 — VLAN segmentation (`scripts/02-vlan.sh`)
Four hosts on one bridge, split into VLAN 100 and VLAN 200.

| Test | Hosts | VLANs | Result |
|------|-------|-------|--------|
| 1 | ns1 → ns3 | 100 → 100 | ✅ reachable |
| 2 | ns1 → ns2 | 100 → 200 | ❌ **blocked** (same subnet!) |
| 3 | ns2 → ns4 | 200 → 200 | ✅ reachable |

**Takeaway:** VLAN tags isolate L2 domains even when hosts share an IP subnet — the
basis of multi-tenant isolation. **Skills:** 802.1Q VLAN tagging, access ports.

![VLAN isolation](screenshots/02-vlan-isolation.png)

---

## Lab 3 — VXLAN overlay tunnel (`scripts/03-vxlan.sh`)
Two "physical servers" on an underlay (`172.16.0.0/24`) carry a virtual overlay
(`192.168.99.0/24`) inside a VXLAN tunnel (VNI 42).

**Proof (tcpdump on the underlay while pinging the overlay):**
```
172.16.0.1.49940 > 172.16.0.2.4789: VXLAN, flags [I], vni 42
172.16.0.2.37150 > 172.16.0.1.4789: VXLAN, flags [I], vni 42
```
The overlay ICMP is encapsulated in **UDP/4789 VXLAN** — how every cloud carries
tenant traffic across a shared physical network.
**Skills:** VXLAN/Geneve overlays, underlay vs overlay, encapsulation, packet capture.

![VXLAN overlay](screenshots/03-vxlan-overlay.png)

---

## Lab 4 — OpenFlow programming (`scripts/04-openflow.sh`)
A bridge in `secure` fail-mode (no default forwarding). Traffic only flows when I
hand-write OpenFlow rules — then a higher-priority rule acts as a firewall.

```
1. No flows           -> ping BLOCKED (secure mode, nothing forwards)
2. Add forwarding      (priority=10)  -> ping WORKS
3. Add icmp drop       (priority=100) -> ping BLOCKED at the flow level
```
**Gotcha I learned:** flows added without a priority default to `priority=32768`, so
my first drop rule (`priority=100`) never matched. Lowering the forwarding rules to
`priority=10` made the firewall work — a lesson in OpenFlow match precedence.
**Skills:** OpenFlow flow programming, priorities, match/action, datapath control.

![OpenFlow firewall](screenshots/04-openflow-firewall.png)

---

## Lab 5 — Kubernetes pod networking (`scripts/05-k8s-pod-networking.sh`)
A real single-node **k3s** cluster. Deploy pods, prove pod-to-pod connectivity, and
reveal that the CNI uses the **same bridge + VXLAN tech** as Labs 1 and 3.

```
client pod (10.42.0.10) --curl--> web pod (10.42.0.9)   OK
                        --curl--> web pod (10.42.0.11)  OK
Service web (ClusterIP 10.43.128.88) --> load-balances across both web pods
```
**The connection that matters:** Kubernetes' Flannel CNI created a Linux bridge
`cni0` and a VXLAN device `flannel.1`:
```
flannel.1: vxlan id 1 local 192.168.5.15 dev eth0 dstport 8472
cni0:      10.42.0.1/24   (pods attach here via veth — exactly like Lab 1)
```
So **everything in Labs 1–3 is literally how Kubernetes networks pods.** Pod traffic
to another node rides a VXLAN overlay (Lab 3); pods on a node share a bridge (Lab 1).
**Skills:** Kubernetes pods/deployments/services, CNI, pod networking, ClusterIP.

> Setup: `curl -sfL https://get.k3s.io | sh -`, then `sudo bash scripts/05-k8s-pod-networking.sh`

---

## A quick visual: all the virtual switches built
![ovs-vsctl show](screenshots/05-ovs-vsctl-show.png)

---

## Run it yourself
On a Mac: `brew install lima && limactl start template://ubuntu-lts`, then inside:
```bash
sudo apt-get update
sudo apt-get install -y openvswitch-switch tcpdump iproute2
sudo bash scripts/01-l2-switch.sh
sudo bash scripts/02-vlan.sh
sudo bash scripts/03-vxlan.sh
sudo bash scripts/04-openflow.sh
sudo bash scripts/cleanup.sh   # tidy up
```
On bare-metal Linux, skip Lima and run the scripts directly.

## Roadmap (next labs)
- [x] Kubernetes pod networking with a CNI (k3s + Flannel) — **Lab 5**
- [ ] OVN-Kubernetes (OVS-based CNI) pod networking
- [ ] Throughput & pps benchmarking through OVS (iperf3) + the DPU-offload story
- [ ] A small Go tool that reads OVS state via OVSDB

---
*Author: Sridhar Panigrahi · B.Tech (AI/ML), Polaris School of Technology*
