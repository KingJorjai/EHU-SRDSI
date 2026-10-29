#!/usr/bin/env bash
echo "MV2 — vecino 10.0.3.11 antes/después del ARP spoof"
echo
ip neigh show 10.0.3.11
echo
echo "ping 10.0.3.11 (red NO protegida)"
ping -c 2 -W 1 10.0.3.11
echo
echo "ping 1.1.1.1 (MACsec)"
ping -c 2 -W 1 1.1.1.1
echo
echo "MACsec sigue funcionando aunque la red no protegida esté envenenada"
sleep 30
