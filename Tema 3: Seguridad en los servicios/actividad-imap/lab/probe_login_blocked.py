#!/usr/bin/env python3
"""Intento de LOGIN en claro (credenciales ficticias) para comprobar
que el servidor aplica LOGINDISABLED y rechaza la autenticacion."""
import socket
import sys

HOST = sys.argv[1] if len(sys.argv) > 1 else "ikasle.ehu.eus"
s = socket.create_connection((HOST, 143), timeout=8)
s.settimeout(5)
print(s.recv(4096).decode(errors="replace"), end="")
s.sendall(b"a1 LOGIN usuario_prueba clave_prueba\r\n")
print(s.recv(4096).decode(errors="replace"), end="")
s.sendall(b"a2 LOGOUT\r\n")
print(s.recv(4096).decode(errors="replace"), end="")
s.close()
