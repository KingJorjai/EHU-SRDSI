sudo apt install telnet telnetd


sudo vi /etc/inetd.conf 

Quitar comentario:
telnet  stream  tcp     nowait  root    /usr/sbin/tcpd  /usr/sbin/telnetd

sudo systemctl restart inetd

user1@bocata-jamon:~$ ss -tan
State      Recv-Q      Send-Q           Local Address:Port           Peer Address:Port     
LISTEN     0           128                    0.0.0.0:22                  0.0.0.0:*        
LISTEN     0           10                     0.0.0.0:23                  0.0.0.0:*        
LISTEN     0           128                       [::]:22                     [::]:*        
user1@bocata-jamon:~$ 


## Wireshark
Escuchar en loopback
SSHv2 -> Follow stream


## SSH debug

```
user1@bocata-jamon:~$ ssh -v user2@localhost
debug1: OpenSSH_10.0p2 Debian-7+deb13u4, OpenSSL 3.5.7 9 Jun 2026
debug1: Reading configuration data /etc/ssh/ssh_config
debug1: Reading configuration data /etc/ssh/ssh_config.d/20-systemd-ssh-proxy.conf
debug1: /etc/ssh/ssh_config line 21: Applying options for *
debug1: Connecting to localhost [::1] port 22.
debug1: Connection established.
debug1: identity file /home/user1/.ssh/id_rsa type -1
debug1: identity file /home/user1/.ssh/id_rsa-cert type -1
debug1: identity file /home/user1/.ssh/id_ecdsa type -1
debug1: identity file /home/user1/.ssh/id_ecdsa-cert type -1
debug1: identity file /home/user1/.ssh/id_ecdsa_sk type -1
debug1: identity file /home/user1/.ssh/id_ecdsa_sk-cert type -1
debug1: identity file /home/user1/.ssh/id_ed25519 type -1
debug1: identity file /home/user1/.ssh/id_ed25519-cert type -1
debug1: identity file /home/user1/.ssh/id_ed25519_sk type -1
debug1: identity file /home/user1/.ssh/id_ed25519_sk-cert type -1
debug1: identity file /home/user1/.ssh/id_xmss type -1
debug1: identity file /home/user1/.ssh/id_xmss-cert type -1
debug1: Local version string SSH-2.0-OpenSSH_10.0p2 Debian-7+deb13u4
debug1: Remote protocol version 2.0, remote software version OpenSSH_10.0p2 Debian-7+deb13u4
debug1: compat_banner: match: OpenSSH_10.0p2 Debian-7+deb13u4 pat OpenSSH* compat 0x04000000
debug1: Authenticating to localhost:22 as 'user2'
debug1: load_hostkeys: fopen /home/user1/.ssh/known_hosts2: No such file or directory
debug1: load_hostkeys: fopen /etc/ssh/ssh_known_hosts: No such file or directory
debug1: load_hostkeys: fopen /etc/ssh/ssh_known_hosts2: No such file or directory
debug1: SSH2_MSG_KEXINIT sent
debug1: SSH2_MSG_KEXINIT received
debug1: kex: algorithm: mlkem768x25519-sha256
debug1: kex: host key algorithm: ssh-ed25519
debug1: kex: server->client cipher: chacha20-poly1305@openssh.com MAC: <implicit> compression: none
debug1: kex: client->server cipher: chacha20-poly1305@openssh.com MAC: <implicit> compression: none
debug1: expecting SSH2_MSG_KEX_ECDH_REPLY
debug1: SSH2_MSG_KEX_ECDH_REPLY received
debug1: Server host key: ssh-ed25519 SHA256:fiVXvroD0pHkDSJAUdvUNS2gWp/KZ9ffVNK6Q8AdU0w
debug1: load_hostkeys: fopen /home/user1/.ssh/known_hosts2: No such file or directory
debug1: load_hostkeys: fopen /etc/ssh/ssh_known_hosts: No such file or directory
debug1: load_hostkeys: fopen /etc/ssh/ssh_known_hosts2: No such file or directory
debug1: Host 'localhost' is known and matches the ED25519 host key.
debug1: Found key in /home/user1/.ssh/known_hosts:1
debug1: ssh_packet_send2_wrapped: resetting send seqnr 3
debug1: rekey out after 134217728 blocks
debug1: SSH2_MSG_NEWKEYS sent
debug1: Sending SSH2_MSG_EXT_INFO
debug1: expecting SSH2_MSG_NEWKEYS
debug1: ssh_packet_read_poll2: resetting read seqnr 3
debug1: SSH2_MSG_NEWKEYS received
debug1: rekey in after 134217728 blocks
debug1: SSH2_MSG_EXT_INFO received
debug1: kex_ext_info_client_parse: server-sig-algs=<ssh-ed25519,ecdsa-sha2-nistp256,ecdsa-sha2-nistp384,ecdsa-sha2-nistp521,sk-ssh-ed25519@openssh.com,sk-ecdsa-sha2-nistp256@openssh.com,rsa-sha2-512,rsa-sha2-256>
debug1: kex_ext_info_check_ver: publickey-hostbound@openssh.com=<0>
debug1: kex_ext_info_check_ver: ping@openssh.com=<0>
debug1: SSH2_MSG_SERVICE_ACCEPT received
debug1: SSH2_MSG_EXT_INFO received
debug1: kex_ext_info_client_parse: server-sig-algs=<ssh-ed25519,ecdsa-sha2-nistp256,ecdsa-sha2-nistp384,ecdsa-sha2-nistp521,sk-ssh-ed25519@openssh.com,sk-ecdsa-sha2-nistp256@openssh.com,rsa-sha2-512,rsa-sha2-256>
debug1: Authentications that can continue: publickey,password
debug1: Next authentication method: publickey
debug1: get_agent_identities: bound agent to hostkey
debug1: get_agent_identities: ssh_fetch_identitylist: agent contains no identities
debug1: Will attempt key: /home/user1/.ssh/id_rsa 
debug1: Will attempt key: /home/user1/.ssh/id_ecdsa 
debug1: Will attempt key: /home/user1/.ssh/id_ecdsa_sk 
debug1: Will attempt key: /home/user1/.ssh/id_ed25519 
debug1: Will attempt key: /home/user1/.ssh/id_ed25519_sk 
debug1: Will attempt key: /home/user1/.ssh/id_xmss 
debug1: Trying private key: /home/user1/.ssh/id_rsa
debug1: Trying private key: /home/user1/.ssh/id_ecdsa
debug1: Trying private key: /home/user1/.ssh/id_ecdsa_sk
debug1: Trying private key: /home/user1/.ssh/id_ed25519
debug1: Trying private key: /home/user1/.ssh/id_ed25519_sk
debug1: Trying private key: /home/user1/.ssh/id_xmss
debug1: Next authentication method: password
user2@localhost's password: 
Authenticated to localhost ([::1]:22) using "password".
debug1: channel 0: new session [client-session] (inactive timeout: 0)
debug1: Requesting no-more-sessions@openssh.com
debug1: Entering interactive session.
debug1: pledge: filesystem
debug1: client_input_global_request: rtype hostkeys-00@openssh.com want_reply 0
debug1: client_input_hostkeys: searching /home/user1/.ssh/known_hosts for localhost / (none)
debug1: client_input_hostkeys: searching /home/user1/.ssh/known_hosts2 for localhost / (none)
debug1: client_input_hostkeys: hostkeys file /home/user1/.ssh/known_hosts2 does not exist
debug1: client_input_hostkeys: no new or deprecated keys from server
debug1: Sending environment.
debug1: channel 0: setting env COLORTERM = "truecolor"
debug1: channel 0: setting env LANG = "es_ES.UTF-8"
debug1: pledge: fork
Linux bocata-jamon 6.12.107+deb13-amd64 #1 SMP PREEMPT_DYNAMIC Debian 6.12.107-1 (2026-08-29) x86_64

The programs included with the Debian GNU/Linux system are free software;
the exact distribution terms for each program are described in the
individual files in /usr/share/doc/*/copyright.

Debian GNU/Linux comes with ABSOLUTELY NO WARRANTY, to the extent
permitted by applicable law.
Last login: Fri Oct  2 12:42:07 2026 from ::1
user2@bocata-jamon:~$ 
cerrar sesión
debug1: client_input_channel_req: channel 0 rtype exit-status reply 0
debug1: client_input_channel_req: channel 0 rtype eow@openssh.com reply 0
debug1: channel 0: free: client-session, nchannels 1
Connection to localhost closed.
Transferred: sent 3644, received 4348 bytes, in 3.9 seconds
Bytes per second: sent 931.8, received 1111.8
debug1: Exit status 0
user1@bocata-jamon:~$ 
```

```
user1@bocata-jamon:~$ ssh -vv user2@localhost
debug1: OpenSSH_10.0p2 Debian-7+deb13u4, OpenSSL 3.5.7 9 Jun 2026
debug1: Reading configuration data /etc/ssh/ssh_config
debug1: Reading configuration data /etc/ssh/ssh_config.d/20-systemd-ssh-proxy.conf
debug1: /etc/ssh/ssh_config line 21: Applying options for *
debug2: resolving "localhost" port 22
debug1: Connecting to localhost [::1] port 22.
debug1: Connection established.
debug1: identity file /home/user1/.ssh/id_rsa type -1
debug1: identity file /home/user1/.ssh/id_rsa-cert type -1
debug1: identity file /home/user1/.ssh/id_ecdsa type -1
debug1: identity file /home/user1/.ssh/id_ecdsa-cert type -1
debug1: identity file /home/user1/.ssh/id_ecdsa_sk type -1
debug1: identity file /home/user1/.ssh/id_ecdsa_sk-cert type -1
debug1: identity file /home/user1/.ssh/id_ed25519 type -1
debug1: identity file /home/user1/.ssh/id_ed25519-cert type -1
debug1: identity file /home/user1/.ssh/id_ed25519_sk type -1
debug1: identity file /home/user1/.ssh/id_ed25519_sk-cert type -1
debug1: identity file /home/user1/.ssh/id_xmss type -1
debug1: identity file /home/user1/.ssh/id_xmss-cert type -1
debug1: Local version string SSH-2.0-OpenSSH_10.0p2 Debian-7+deb13u4
debug1: Remote protocol version 2.0, remote software version OpenSSH_10.0p2 Debian-7+deb13u4
debug1: compat_banner: match: OpenSSH_10.0p2 Debian-7+deb13u4 pat OpenSSH* compat 0x04000000
debug2: fd 3 setting O_NONBLOCK
debug1: Authenticating to localhost:22 as 'user2'
debug1: load_hostkeys: fopen /home/user1/.ssh/known_hosts2: No such file or directory
debug1: load_hostkeys: fopen /etc/ssh/ssh_known_hosts: No such file or directory
debug1: load_hostkeys: fopen /etc/ssh/ssh_known_hosts2: No such file or directory
debug1: SSH2_MSG_KEXINIT sent
debug1: SSH2_MSG_KEXINIT received
debug2: local client KEXINIT proposal
debug2: KEX algorithms: mlkem768x25519-sha256,sntrup761x25519-sha512,sntrup761x25519-sha512@openssh.com,curve25519-sha256,curve25519-sha256@libssh.org,ecdh-sha2-nistp256,ecdh-sha2-nistp384,ecdh-sha2-nistp521,diffie-hellman-group-exchange-sha256,diffie-hellman-group16-sha512,diffie-hellman-group18-sha512,diffie-hellman-group14-sha256,ext-info-c,kex-strict-c-v00@openssh.com
debug2: host key algorithms: ssh-ed25519-cert-v01@openssh.com,ecdsa-sha2-nistp256-cert-v01@openssh.com,ecdsa-sha2-nistp384-cert-v01@openssh.com,ecdsa-sha2-nistp521-cert-v01@openssh.com,sk-ssh-ed25519-cert-v01@openssh.com,sk-ecdsa-sha2-nistp256-cert-v01@openssh.com,rsa-sha2-512-cert-v01@openssh.com,rsa-sha2-256-cert-v01@openssh.com,ssh-ed25519,ecdsa-sha2-nistp256,ecdsa-sha2-nistp384,ecdsa-sha2-nistp521,sk-ssh-ed25519@openssh.com,sk-ecdsa-sha2-nistp256@openssh.com,rsa-sha2-512,rsa-sha2-256
debug2: ciphers ctos: chacha20-poly1305@openssh.com,aes128-gcm@openssh.com,aes256-gcm@openssh.com,aes128-ctr,aes192-ctr,aes256-ctr
debug2: ciphers stoc: chacha20-poly1305@openssh.com,aes128-gcm@openssh.com,aes256-gcm@openssh.com,aes128-ctr,aes192-ctr,aes256-ctr
debug2: MACs ctos: umac-64-etm@openssh.com,umac-128-etm@openssh.com,hmac-sha2-256-etm@openssh.com,hmac-sha2-512-etm@openssh.com,hmac-sha1-etm@openssh.com,umac-64@openssh.com,umac-128@openssh.com,hmac-sha2-256,hmac-sha2-512,hmac-sha1
debug2: MACs stoc: umac-64-etm@openssh.com,umac-128-etm@openssh.com,hmac-sha2-256-etm@openssh.com,hmac-sha2-512-etm@openssh.com,hmac-sha1-etm@openssh.com,umac-64@openssh.com,umac-128@openssh.com,hmac-sha2-256,hmac-sha2-512,hmac-sha1
debug2: compression ctos: none,zlib@openssh.com
debug2: compression stoc: none,zlib@openssh.com
debug2: languages ctos: 
debug2: languages stoc: 
debug2: first_kex_follows 0 
debug2: reserved 0 
debug2: peer server KEXINIT proposal
debug2: KEX algorithms: mlkem768x25519-sha256,sntrup761x25519-sha512,sntrup761x25519-sha512@openssh.com,curve25519-sha256,curve25519-sha256@libssh.org,ecdh-sha2-nistp256,ecdh-sha2-nistp384,ecdh-sha2-nistp521,ext-info-s,kex-strict-s-v00@openssh.com
debug2: host key algorithms: rsa-sha2-512,rsa-sha2-256,ecdsa-sha2-nistp256,ssh-ed25519
debug2: ciphers ctos: chacha20-poly1305@openssh.com,aes128-gcm@openssh.com,aes256-gcm@openssh.com,aes128-ctr,aes192-ctr,aes256-ctr
debug2: ciphers stoc: chacha20-poly1305@openssh.com,aes128-gcm@openssh.com,aes256-gcm@openssh.com,aes128-ctr,aes192-ctr,aes256-ctr
debug2: MACs ctos: umac-64-etm@openssh.com,umac-128-etm@openssh.com,hmac-sha2-256-etm@openssh.com,hmac-sha2-512-etm@openssh.com,hmac-sha1-etm@openssh.com,umac-64@openssh.com,umac-128@openssh.com,hmac-sha2-256,hmac-sha2-512,hmac-sha1
debug2: MACs stoc: umac-64-etm@openssh.com,umac-128-etm@openssh.com,hmac-sha2-256-etm@openssh.com,hmac-sha2-512-etm@openssh.com,hmac-sha1-etm@openssh.com,umac-64@openssh.com,umac-128@openssh.com,hmac-sha2-256,hmac-sha2-512,hmac-sha1
debug2: compression ctos: none,zlib@openssh.com
debug2: compression stoc: none,zlib@openssh.com
debug2: languages ctos: 
debug2: languages stoc: 
debug2: first_kex_follows 0 
debug2: reserved 0 
debug1: kex: algorithm: mlkem768x25519-sha256
debug1: kex: host key algorithm: ssh-ed25519
debug1: kex: server->client cipher: chacha20-poly1305@openssh.com MAC: <implicit> compression: none
debug1: kex: client->server cipher: chacha20-poly1305@openssh.com MAC: <implicit> compression: none
debug1: expecting SSH2_MSG_KEX_ECDH_REPLY
debug1: SSH2_MSG_KEX_ECDH_REPLY received
debug1: Server host key: ssh-ed25519 SHA256:fiVXvroD0pHkDSJAUdvUNS2gWp/KZ9ffVNK6Q8AdU0w
debug1: load_hostkeys: fopen /home/user1/.ssh/known_hosts2: No such file or directory
debug1: load_hostkeys: fopen /etc/ssh/ssh_known_hosts: No such file or directory
debug1: load_hostkeys: fopen /etc/ssh/ssh_known_hosts2: No such file or directory
debug1: Host 'localhost' is known and matches the ED25519 host key.
debug1: Found key in /home/user1/.ssh/known_hosts:1
debug1: ssh_packet_send2_wrapped: resetting send seqnr 3
debug2: ssh_set_newkeys: mode 1
debug1: rekey out after 134217728 blocks
debug1: SSH2_MSG_NEWKEYS sent
debug1: Sending SSH2_MSG_EXT_INFO
debug1: expecting SSH2_MSG_NEWKEYS
debug1: ssh_packet_read_poll2: resetting read seqnr 3
debug1: SSH2_MSG_NEWKEYS received
debug2: ssh_set_newkeys: mode 0
debug1: rekey in after 134217728 blocks
debug2: KEX algorithms: mlkem768x25519-sha256,sntrup761x25519-sha512,sntrup761x25519-sha512@openssh.com,curve25519-sha256,curve25519-sha256@libssh.org,ecdh-sha2-nistp256,ecdh-sha2-nistp384,ecdh-sha2-nistp521,diffie-hellman-group-exchange-sha256,diffie-hellman-group16-sha512,diffie-hellman-group18-sha512,diffie-hellman-group14-sha256,ext-info-c,kex-strict-c-v00@openssh.com
debug2: host key algorithms: ssh-ed25519-cert-v01@openssh.com,ecdsa-sha2-nistp256-cert-v01@openssh.com,ecdsa-sha2-nistp384-cert-v01@openssh.com,ecdsa-sha2-nistp521-cert-v01@openssh.com,sk-ssh-ed25519-cert-v01@openssh.com,sk-ecdsa-sha2-nistp256-cert-v01@openssh.com,rsa-sha2-512-cert-v01@openssh.com,rsa-sha2-256-cert-v01@openssh.com,ssh-ed25519,ecdsa-sha2-nistp256,ecdsa-sha2-nistp384,ecdsa-sha2-nistp521,sk-ssh-ed25519@openssh.com,sk-ecdsa-sha2-nistp256@openssh.com,rsa-sha2-512,rsa-sha2-256
debug2: ciphers ctos: chacha20-poly1305@openssh.com,aes128-gcm@openssh.com,aes256-gcm@openssh.com,aes128-ctr,aes192-ctr,aes256-ctr
debug2: ciphers stoc: chacha20-poly1305@openssh.com,aes128-gcm@openssh.com,aes256-gcm@openssh.com,aes128-ctr,aes192-ctr,aes256-ctr
debug2: MACs ctos: umac-64-etm@openssh.com,umac-128-etm@openssh.com,hmac-sha2-256-etm@openssh.com,hmac-sha2-512-etm@openssh.com,hmac-sha1-etm@openssh.com,umac-64@openssh.com,umac-128@openssh.com,hmac-sha2-256,hmac-sha2-512,hmac-sha1
debug2: MACs stoc: umac-64-etm@openssh.com,umac-128-etm@openssh.com,hmac-sha2-256-etm@openssh.com,hmac-sha2-512-etm@openssh.com,hmac-sha1-etm@openssh.com,umac-64@openssh.com,umac-128@openssh.com,hmac-sha2-256,hmac-sha2-512,hmac-sha1
debug2: compression ctos: none,zlib@openssh.com
debug2: compression stoc: none,zlib@openssh.com
debug2: languages ctos: 
debug2: languages stoc: 
debug2: first_kex_follows 0 
debug2: reserved 0 
debug1: SSH2_MSG_EXT_INFO received
debug1: kex_ext_info_client_parse: server-sig-algs=<ssh-ed25519,ecdsa-sha2-nistp256,ecdsa-sha2-nistp384,ecdsa-sha2-nistp521,sk-ssh-ed25519@openssh.com,sk-ecdsa-sha2-nistp256@openssh.com,rsa-sha2-512,rsa-sha2-256>
debug1: kex_ext_info_check_ver: publickey-hostbound@openssh.com=<0>
debug1: kex_ext_info_check_ver: ping@openssh.com=<0>
debug2: service_accept: ssh-userauth
debug1: SSH2_MSG_SERVICE_ACCEPT received
debug1: SSH2_MSG_EXT_INFO received
debug1: kex_ext_info_client_parse: server-sig-algs=<ssh-ed25519,ecdsa-sha2-nistp256,ecdsa-sha2-nistp384,ecdsa-sha2-nistp521,sk-ssh-ed25519@openssh.com,sk-ecdsa-sha2-nistp256@openssh.com,rsa-sha2-512,rsa-sha2-256>
debug1: Authentications that can continue: publickey,password
debug1: Next authentication method: publickey
debug1: get_agent_identities: bound agent to hostkey
debug1: get_agent_identities: ssh_fetch_identitylist: agent contains no identities
debug1: Will attempt key: /home/user1/.ssh/id_rsa 
debug1: Will attempt key: /home/user1/.ssh/id_ecdsa 
debug1: Will attempt key: /home/user1/.ssh/id_ecdsa_sk 
debug1: Will attempt key: /home/user1/.ssh/id_ed25519 
debug1: Will attempt key: /home/user1/.ssh/id_ed25519_sk 
debug1: Will attempt key: /home/user1/.ssh/id_xmss 
debug2: pubkey_prepare: done
debug1: Trying private key: /home/user1/.ssh/id_rsa
debug1: Trying private key: /home/user1/.ssh/id_ecdsa
debug1: Trying private key: /home/user1/.ssh/id_ecdsa_sk
debug1: Trying private key: /home/user1/.ssh/id_ed25519
debug1: Trying private key: /home/user1/.ssh/id_ed25519_sk
debug1: Trying private key: /home/user1/.ssh/id_xmss
debug2: we did not send a packet, disable method
debug1: Next authentication method: password
user2@localhost's password: 
debug2: we sent a password packet, wait for reply
Authenticated to localhost ([::1]:22) using "password".
debug1: channel 0: new session [client-session] (inactive timeout: 0)
debug2: channel 0: send open
debug1: Requesting no-more-sessions@openssh.com
debug1: Entering interactive session.
debug1: pledge: filesystem
debug2: client_loop: session QoS is now interactive
debug2: fd 3 setting TCP_NODELAY
debug1: client_input_global_request: rtype hostkeys-00@openssh.com want_reply 0
debug1: client_input_hostkeys: searching /home/user1/.ssh/known_hosts for localhost / (none)
debug1: client_input_hostkeys: searching /home/user1/.ssh/known_hosts2 for localhost / (none)
debug1: client_input_hostkeys: hostkeys file /home/user1/.ssh/known_hosts2 does not exist
debug1: client_input_hostkeys: no new or deprecated keys from server
debug2: channel_input_open_confirmation: channel 0: callback start
debug2: client_session2_setup: id 0
debug2: channel 0: request pty-req confirm 1
debug1: Sending environment.
debug1: channel 0: setting env COLORTERM = "truecolor"
debug2: channel 0: request env confirm 0
debug1: channel 0: setting env LANG = "es_ES.UTF-8"
debug2: channel 0: request env confirm 0
debug2: channel 0: request shell confirm 1
debug2: channel_set_xtype: labeled channel 0 as session:shell (inactive timeout 0)
debug1: pledge: fork
debug2: channel_input_open_confirmation: channel 0: callback done
debug2: channel 0: open confirm rwindow 0 rmax 32768
debug2: channel_input_status_confirm: type 99 id 0
debug2: PTY allocation request accepted on channel 0
debug2: channel 0: rcvd adjust 2097152
debug2: channel_input_status_confirm: type 99 id 0
debug2: shell request accepted on channel 0
Linux bocata-jamon 6.12.107+deb13-amd64 #1 SMP PREEMPT_DYNAMIC Debian 6.12.107-1 (2026-08-29) x86_64

The programs included with the Debian GNU/Linux system are free software;
the exact distribution terms for each program are described in the
individual files in /usr/share/doc/*/copyright.

Debian GNU/Linux comes with ABSOLUTELY NO WARRANTY, to the extent
permitted by applicable law.
Last login: Fri Oct  2 12:47:00 2026 from ::1
user2@bocata-jamon:~$ 
cerrar sesión
debug2: channel 0: rcvd eof
debug2: channel 0: output open -> drain
debug2: channel 0: obuf empty
debug2: chan_shutdown_write: channel 0: (i0 o1 sock -1 wfd 5 efd 6 [write])
debug2: channel 0: output drain -> closed
debug1: client_input_channel_req: channel 0 rtype exit-status reply 0
debug1: client_input_channel_req: channel 0 rtype eow@openssh.com reply 0
debug2: channel 0: rcvd eow
debug2: chan_shutdown_read: channel 0: (i0 o3 sock -1 wfd 4 efd 6 [write])
debug2: channel 0: input open -> closed
debug2: channel 0: rcvd close
debug2: channel 0: almost dead
debug2: channel 0: gc: notify user
debug2: channel 0: gc: user detached
debug2: channel 0: send_close2
debug2: channel 0: send close for remote id 0
debug2: channel 0: is dead
debug2: channel 0: garbage collecting
debug1: channel 0: free: client-session, nchannels 1
Connection to localhost closed.
Transferred: sent 3644, received 4328 bytes, in 1.7 seconds
Bytes per second: sent 2101.7, received 2496.2
debug1: Exit status 0
user1@bocata-jamon:~$ 
```

## SSH Forwarding

Desde mi máquina local:
```
~ ✗ ssh -L 12000:ehu.eus:443 user1@SRDSI
```

Comprobar que el túnel está abierto
```
~ ❯ sudo netstat -tanp | grep 12000
tcp        0      0 127.0.0.1:12000         0.0.0.0:*               LISTEN      324823/ssh
tcp6       0      0 ::1:12000               :::*                    LISTEN      324823/ssh
```

## SSH Clave pública

Intentamos conectarnos a `user2` desde `user1` y nos pide contraseña.
```
user1@bocata-jamon:~$ ssh user2@localhost
user2@localhost's password: 
Linux bocata-jamon 6.12.107+deb13-amd64 #1 SMP PREEMPT_DYNAMIC Debian 6.12.107-1 (2026-08-29) x86_64

The programs included with the Debian GNU/Linux system are free software;
the exact distribution terms for each program are described in the
individual files in /usr/share/doc/*/copyright.

Debian GNU/Linux comes with ABSOLUTELY NO WARRANTY, to the extent
permitted by applicable law.
Last login: Fri Oct  2 12:49:51 2026 from ::1
user2@bocata-jamon:~$ 
cerrar sesión
Connection to localhost closed.

```

Creamos una par de claver para `user1`:
```
user1@bocata-jamon:~$ ssh-keygen 
Generating public/private ed25519 key pair.
Enter file in which to save the key (/home/user1/.ssh/id_ed25519): 
Enter passphrase for "/home/user1/.ssh/id_ed25519" (empty for no passphrase): 
Enter same passphrase again: 
Your identification has been saved in /home/user1/.ssh/id_ed25519
Your public key has been saved in /home/user1/.ssh/id_ed25519.pub
The key fingerprint is:
SHA256:CYaV3atqkdOvqHiQSWKXBA/VAI1GXnOiGK336QGyCaU user1@bocata-jamon
The key's randomart image is:
+--[ED25519 256]--+
|o***o..o .       |
|o+Bo++. . .      |
|o*..o o    .     |
|E.+o . . ..      |
|oB.= . oS.       |
|o + + + o        |
|   o . + .       |
|   .o o.  .      |
|  ...o. ..       |
+----[SHA256]-----+
```

Ahora copiamos la clave pública de `user1` a `user2`:
```
user1@bocata-jamon:~$ ssh-copy-id user2@localhost
/usr/bin/ssh-copy-id: INFO: Source of key(s) to be installed: "/home/user1/.ssh/id_ed25519.pub"
/usr/bin/ssh-copy-id: INFO: attempting to log in with the new key(s), to filter out any that are already installed
/usr/bin/ssh-copy-id: INFO: 1 key(s) remain to be installed -- if you are prompted now it is to install the new keys
user2@localhost's password: 

Number of key(s) added: 1

Now try logging into the machine, with: "ssh 'user2@localhost'"
and check to make sure that only the key(s) you wanted were added.

user1@bocata-jamon:~$
```

Ahora intentamos conectarnos por ssh a `user2` y no nos pide contraseña:

```
user1@bocata-jamon:~$ ssh user2@localhost
Linux bocata-jamon 6.12.107+deb13-amd64 #1 SMP PREEMPT_DYNAMIC Debian 6.12.107-1 (2026-08-29) x86_64

The programs included with the Debian GNU/Linux system are free software;
the exact distribution terms for each program are described in the
individual files in /usr/share/doc/*/copyright.

Debian GNU/Linux comes with ABSOLUTELY NO WARRANTY, to the extent
permitted by applicable law.
Last login: Fri Oct  2 13:05:10 2026 from ::1
user2@bocata-jamon:~$ 
cerrar sesión
Connection to localhost closed.
user1@bocata-jamon:~$ 
```