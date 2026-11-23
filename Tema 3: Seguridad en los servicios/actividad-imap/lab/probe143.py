#!/usr/bin/env python3
"""Sondeo IMAP en claro (sin autenticarse) contra un servidor real.

Solo lee el saludo y pide CAPABILITY. No envia credenciales.
"""
import socket
import sys

HOST = sys.argv[1] if len(sys.argv) > 1 else "ikasle.ehu.eus"
PORT = int(sys.argv[2]) if len(sys.argv) > 2 else 143

s = socket.create_connection((HOST, PORT), timeout=8)
s.settimeout(5)
try:
    print(s.recv(4096).decode(errors="replace"), end="")
except Exception:
    pass
s.sendall(b"a1 CAPABILITY\r\n")
try:
    print(s.recv(4096).decode(errors="replace"), end="")
except Exception:
    pass
s.sendall(b"a2 LOGOUT\r\n")
try:
    print(s.recv(4096).decode(errors="replace"), end="")
except Exception:
    pass
s.close()
