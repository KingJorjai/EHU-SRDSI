#!/usr/bin/env python3
"""Modifica un byte del payload/cifrado de una trama MACsec y la reenvía.

Uso: sudo python3 forge-icv.py --iface enp0s9 --pcap frame.pcapng
"""
import argparse
from scapy.all import Ether, rdpcap, sendp

p = argparse.ArgumentParser()
p.add_argument("--iface", default="enp0s9")
p.add_argument("--pcap", required=True)
a = p.parse_args()

pkts = rdpcap(a.pcap)
if not pkts:
    raise SystemExit("pcap vacío")
raw = bytearray(bytes(pkts[0]))
if len(raw) < 20:
    raise SystemExit("trama demasiado corta")
raw[-17] ^= 0xFF  # altera el último byte antes del ICV
sendp(Ether(bytes(raw)), iface=a.iface, count=1, verbose=False)
print(f"Trama alterada enviada por {a.iface} (byte -17 modificado)")
