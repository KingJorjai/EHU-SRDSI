#!/usr/bin/env python3
"""STARTTLS limpio contra el servidor IMAP real, sin autenticarse.

Hace el saludo, pide STARTTLS, espera la respuesta y solo entonces
inicia TLS. Asi Wireshark ve claramente el tramo en claro y el TLS.
"""
import socket
import ssl
import sys

HOST = sys.argv[1] if len(sys.argv) > 1 else "ikasle.ehu.eus"


def readline(sock):
    data = b""
    while not data.endswith(b"\r\n"):
        chunk = sock.recv(1)
        if not chunk:
            break
        data += chunk
    return data


s = socket.create_connection((HOST, 143), timeout=8)
s.settimeout(5)
print(readline(s).decode(errors="replace"), end="")

# CAPABILITY explicita antes de STARTTLS: asi Wireshark reconoce el cambio a TLS.
s.sendall(b"a0 CAPABILITY\r\n")
print(readline(s).decode(errors="replace"), end="")
print(readline(s).decode(errors="replace"), end="")

s.sendall(b"a1 STARTTLS\r\n")
print(readline(s).decode(errors="replace"), end="")

ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE
tls = ctx.wrap_socket(s, server_hostname=HOST)
print(f"[TLS] {tls.version()} {tls.cipher()[0]}", flush=True)

tls.sendall(b"a2 CAPABILITY\r\n")
for _ in range(2):
    print(readline(tls).decode(errors="replace"), end="")

tls.sendall(b"a3 LOGOUT\r\n")
for _ in range(2):
    print(readline(tls).decode(errors="replace"), end="")
tls.close()
