#!/bin/bash

echo
echo "*****************"
echo " Fail2ban config "
echo "*****************"
echo

cat <<EOF >> /etc/fail2ban/filter.d/openvpn.local
[Definition]

# Example messages (other matched messages not seen in the testing server's logs):
# Fri Sep 23 11:55:36 2016 TLS Error: incoming packet authentication failed from [AF_INET]59.90.146.160:51223
# Thu Aug 25 09:36:02 2016 117.207.115.143:58922 TLS Error: TLS handshake failed

failregex =  TLS Error: incoming packet authentication failed from \[AF_INET\]<HOST>:\d+$
             <HOST>:\d+ Connection reset, restarting
             <HOST>:\d+ TLS Auth Error
             <HOST>:\d+ TLS Error: TLS handshake failed$
             <HOST>:\d+ VERIFY ERROR

ignoreregex =
EOF


cat <<EOF >> /etc/fail2ban/jail.d/openvpn.conf
[openvpn]
enabled  = $FAIL2BAN_ENABLED
port     = 1194
protocol = udp
filter   = openvpn
logpath  = /var/log/openvpn.log
maxretry = $FAIL2BAN_MAXRETRIES
EOF

cat <<EOF >> /etc/fail2ban/fail2ban.local
[Definition]
logtarget = /var/log/fail2ban.log
EOF

touch /var/log/openvpn.log
service fail2ban start

