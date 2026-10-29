#!/usr/bin/env bash
ip macsec show
echo
ping -c 3 1.1.1.1
echo
echo "Captura MV2: MACsec + ping"
sleep 30
