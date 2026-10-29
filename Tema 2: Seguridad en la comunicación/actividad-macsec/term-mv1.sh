#!/usr/bin/env bash
ip macsec show
echo
ping -c 3 1.1.1.2
echo
echo "Captura MV1: MACsec + ping"
sleep 30
