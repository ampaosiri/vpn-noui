# vpn-noui
# sudo nano setup-openvpn-2fa.sh
# chmod +x setup-openvpn-2fa.sh
# ./setup-openvpn-2fa.sh

# cd cd OpenVPN-2FA-GoogleAuth/
# chmod +x *.sh
# ./openvpn-install.sh


Checking for IPv6 connectivity...

Your host does not appear to have IPv6 connectivity.

Do you want to enable IPv6 support (NAT)? [y/n]: n

What port do you want OpenVPN to listen to?
   1) Default: 1194
   2) Custom
   3) Random [49152-65535]
Port choice [1-3]: 1

What protocol do you want OpenVPN to use?
UDP is faster. Unless it is not available, you shouldn't use TCP.
   1) UDP
   2) TCP
Protocol [1-2]: 1

What DNS resolvers do you want to use with the VPN?
   1) Current system resolvers (from /etc/resolv.conf)
   2) Self-hosted DNS Resolver (Unbound)
   3) Cloudflare (Anycast: worldwide)
   4) Quad9 (Anycast: worldwide)
   5) Quad9 uncensored (Anycast: worldwide)
   6) FDN (France)
   7) DNS.WATCH (Germany)
   8) OpenDNS (Anycast: worldwide)
   9) Google (Anycast: worldwide)
   10) Yandex Basic (Russia)
   11) AdGuard DNS (Anycast: worldwide)
   12) NextDNS (Anycast: worldwide)
   13) Custom
DNS [1-12]: 11

Do you want to use compression? It is not recommended since the VORACLE attack makes use of it.
Enable compression? [y/n]: n

Do you want to customize encryption settings?
Unless you know what you're doing, you should stick with the default parameters provided by the script.
Note that whatever you choose, all the choices presented in the script are safe. (Unlike OpenVPN's defaults)
See https://github.com/angristan/openvpn-install#security-and-encryption to learn more.

Customize encryption settings? [y/n]: n


# sudo nano openvpn.pam.template
# sudo cp openvpn.pam.template /etc/pam.d/openvpn
# ./manage.sh batch-create

Enter usernames (one per line). End input with an empty line:
Username: openvpn01
Username: openvpn02
Username: openvpn03
Username: openvpn04
Username: openvpn05
Username: 

Creating user: openvpn01

# cd /opt/openvpn/clients
# ./create-zip.sh

scp -i ~/.ssh/key -r root@ip:/opt/openvpn/clients/ ~/Downloads/VPN-ZIP
