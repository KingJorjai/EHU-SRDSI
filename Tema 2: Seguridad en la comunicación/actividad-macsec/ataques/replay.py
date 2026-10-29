#!/usr/bin/env python3
"""Reenvía las tramas de un pcap por una interfaz.

Uso: sudo python3 replay.py --iface enp0s9 --pcap replay.pcapng [--count 3]
"""
import argparse
from scapy.all import rdpcap, sendp

p = argparse.ArgumentParser()
p.add_argument("--iface", default="enp0s9")
p.add_argument("--pcap", required=True)
p.add_argument("--count", type=int, default=1)
p.add_argument("--interval", type=float, default=0.2)
a = p.parse_args()

pkts = rdpcap(a.pcap)
if not pkts:
    raise SystemExit("pcap vacío")
print(f"Reenviando {len(pkts)} trama(s) de {a.pcap} por {a.iface} ({a.count} vez/veces)")
sendp(pkts, iface=a.iface, count=a.count, inter=a.interval, verbose=False)
print("Hecho")
