#!/usr/bin/env python3
"""Sesion SMTP manual (sin autenticarse) para capturar con Wireshark.

Conecta al puerto 25, saluda con EHLO y cierra con QUIT. No envia
credenciales ni correo.
"""
import socket
import sys

HOST = sys.argv[1] if len(sys.argv) > 1 else "smtp.ehu.es"
PORT = int(sys.argv[2]) if len(sys.argv) > 2 else 25


def recv_reply(s):
    data = b""
    s.settimeout(4)
    try:
        while True:
            chunk = s.recv(4096)
            if not chunk:
                break
            data += chunk
            # respuesta completa: linea "250 " (espacio) o "250-..." multilinea
            if b"\r\n" in data:
                last = data.rstrip(b"\r\n").split(b"\r\n")[-1]
                if len(last) >= 4 and last[3:4] == b" ":
                    break
    except socket.timeout:
        pass
    return data.decode(errors="replace")


s = socket.create_connection((HOST, PORT), timeout=8)
print(recv_reply(s), end="")
s.sendall(b"EHLO srdsi.lab\r\n")
print(recv_reply(s), end="")
s.sendall(b"QUIT\r\n")
print(recv_reply(s), end="")
s.close()
