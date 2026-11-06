# OpenVPN Server with Certificate Authentication

This will create an OpenVPN server that authenticates users with individual client certificates.
The container will automatically generate the CA and the server certificate on the first run.
A volume is created for data persistence.

Forked from [wheelybird/openvpn-server-ldap-otp](https://github.com/wheelybird/openvpn-server-ldap-otp).

## Changes compared to the original image

* Ubuntu 26.04 base; OpenVPN is installed from the upstream OpenVPN apt repository (`stable` channel, 2.7.x). Clients from OpenVPN 2.4 on, with old or new client configurations, keep working.
* LDAP and OTP authentication have been removed; `USE_CLIENT_CERTIFICATE`, `LDAP_*` and `ENABLE_OTP` are ignored.
* Every user gets an individual certificate: `generate-client-cert`, `list-users`, `revoke-cert`, `show-client-config <username>`.
* Revoked client certificates are rejected (`crl-verify`). The CRL is regenerated on every start; a client that is already connected with a revoked certificate is dropped at the next TLS renegotiation (hourly by default).
* Client certificates are valid for `CLIENT_CERT_EXPIRE` days (825 by default).
* An existing CA is never recreated automatically (only with `REGENERATE_CERTS=true`). A missing server certificate is issued from the existing CA, so existing PKIs keep working after an upgrade.
* Routing: `OVPN_REMOTE_ROUTES`, `OVPN_LOCAL_ROUTES` and `OVPN_REDIRECT_GATEWAY`; `OVPN_ROUTES` is still accepted as a deprecated alias for `OVPN_REMOTE_ROUTES`.
* Migration: existing installations with `OVPN_REMOTE_ROUTES` set and no explicit `OVPN_REDIRECT_GATEWAY` switch to split tunnel. Set `OVPN_REDIRECT_GATEWAY=true` to keep full tunnel.
* New network options: `OVPN_TOPOLOGY`, `OVPN_POOL_PERSIST`, `OVPN_DUPLICATE_CN`, `OVPN_CLIENT_TO_CLIENT`, `OVPN_CLIENT_CONFIG_DIR`.
* The management interface listens on `127.0.0.1` by default (`OVPN_MANAGEMENT_ADDRESS`).
* Only ECDHE key exchange is used (`dh none`), so no DH parameters are generated.
* OpenVPN always runs as PID 1, also with fail2ban: the container stops if OpenVPN dies.

### A note about compression

Compression is no longer enabled by default for backwards-compatibility. However, the backwards-compatible option compress migrate has been added to the server configuration. This simply allows the server to ignore the client's request for compression. More information on why compression is disabled can be found on the OpenVPN website.

## Configuration

Configuration is via environmental variables.  Here's a list, along with the default value in brackets:

### Mandatory settings:

 * `OVPN_SERVER_CN`:  The CN of the CA and the endpoint hostname the client will use to connect to the OpenVPN server. e.g. `openvpn.example.org`.  Changing it later keeps the certificates; only newly generated client configurations will use the new hostname.

### Optional settings:

 * `OVPN_TLS_CIPHERS` (TLS-ECDHE-ECDSA-WITH-CHACHA20-POLY1305-SHA256:TLS-ECDHE-RSA-WITH-CHACHA20-POLY1305-SHA256:TLS-ECDHE-ECDSA-WITH-AES-128-GCM-SHA256:TLS-ECDHE-RSA-WITH-AES-128-GCM-SHA256): Determines which ciphers will be set for `tls-cipher` in the openvpn config file.
 * `OVPN_TLS_CIPHERSUITES` (TLS-AES-256-GCM-SHA384:TLS-CHACHA20-POLY1305-SHA256:TLS-AES-128-GCM-SHA256:TLS-AES-128-CCM-8-SHA256:TLS-AES-128-CCM-SHA256): Determines which ciphers will be set for `tls-ciphersuites` in the openvpn config file. (Used for TLS 1.3)
 * `OVPN_PORT` (1194): Sets the port that OpenVPN listens on _inside_ the Docker container.  To get the container to listen on the port too, update the Docker `-p` argument to match (e.g., if you set `OVPN_PORT=1196`, use `-p 1196:1196`).  The client configuration will be set to connect to this port too.
 * `OVPN_PROTOCOL` (udp):  The protocol OpenVPN uses.  Either `udp` or `tcp`.
 * `OVPN_INTERFACE_NAME` (tun):  The name of the network tunnel interface OpenVPN uses.
 * `OVPN_NETWORK` (10.50.50.0 255.255.255.0):  The network that will be used the the VPN in `network_address netmask` format.
 * `OVPN_NAT` (true):  If set to true then the client traffic will be masqueraded by the OpenVPN server.  This allows you to connect to targets on the other side of the tunnel without needing to add return routes to those targets (the targets will see the OpenVPN server's IP rather than the client's).
 * `OVPN_DNS_SERVERS` (_undefined_):  A comma-separated list of DNS nameservers to push to the client.  Set this if the remote network has its own DNS or if you route all traffic through the VPN and the remote side blocks access to external name servers.  Note that not all OpenVPN clients will automatically use these nameservers.  e.g. `8.8.8.8,8.8.4.4`
 * `OVPN_DNS_SEARCH_DOMAIN` (_undefined_):  If using the remote network's DNS server then push the search domain (or domains) to the client.  This will allow the client to lookup by hostnames rather than fully-qualified domain names.  i.e. setting this to `example.org` will allow `ping remotehost` instead of `ping remotehost.example.org`.  Separate multiple domains with commas, e.g. `example.org,wheelybird.com,test.net`.
 * `OVPN_REGISTER_DNS` (false): Include `register-dns` in the client config, which is a Windows client option that can force some clients to load the DNS configuration.
 * `OVPN_IDLE_TIMEOUT` (_undefined_): The number of seconds before an idle VPN connection will be disconnected.  This also prevents the client reconnecting due to a keepalive heartbeat timeout.  You might want to use this setting for compliance reasons (e.g. PCI_DSS).  See [Keepalive settings](#keepalive_settings) for more information.
 * `OVPN_VERBOSITY` (3):  The verbosity of OpenVPN's logs.
 * `OVPN_DEFAULT_SERVER` (true): If true, the OpenVPN `server <network> <netmask>` directive will be generated in the server configuration file. If `false`, you have to configure the server yourself by using `OVPN_EXTRA`.
 * `OVPN_EXTRA` (_undefined_): Additional configuration options which will be appended verbatim to the server configuration.
 * `IPTABLES_EXTRA_FILE` (_undefined_): Path of a file containing additional network rules which will be appended to the iptables configuration. Uses the `iptables-save` / `iptables-restore` syntax.

 * `OVPN_MANAGEMENT_ENABLE` (false): Enable the TCP management interface on port 5555. This service allows raw TCP and telnet connections, check [the OpenVPN documentation](https://openvpn.net/community-resources/management-interface/) for further information.
 * `OVPN_MANAGEMENT_ADDRESS` (127.0.0.1): The address the management interface listens on. Set it to `0.0.0.0` to reach the interface through a published port; the protocol is not encrypted.
 * `OVPN_MANAGEMENT_NOAUTH` (false): Allow access to the management interface without any authentication. Note that this option should only be enabled if the management port is not accessible to the internet.
 * `OVPN_MANAGEMENT_PASSWORD` (_undefined_): The password for the management interface. This has to be set if the interface is enabled and the `OVPN_MANAGEMENT_NOAUTH` option is not set. Note that this password is stored in clear-text internally.

 * `REGENERATE_CERTS` (false):  Recreate the whole PKI on start: the CA, the server certificate and all client certificates.  Unset it afterwards, otherwise the PKI is recreated on every start.
 * `KEY_LENGTH` (2048):  The length of the RSA keys in bits.  Higher is more secure, but will take longer to generate.  e.g. `4096`
 * `CLIENT_CERT_EXPIRE` (825):  The validity of new client certificates in days.
 * `DEBUG` (false):  Add debugging information to the logs.
 * `LOG_TO_STDOUT` (true):  Sends *OpenVPN* logs directly to stdout.  If this is set to `false` then the logs are written to `/etc/openvpn/logs/openvpn.log` first, although this file is tailed to stdout once OpenVPN has started.  If `FAIL2BAN_ENABLED` is `true` then this is set to `false` because *fail2ban* needs to be able to parse the *OpenVPN* logs. 
 
 * `FAIL2BAN_ENABLED` (false):  Set to `true` to enable the fail2ban daemon (protection against brute force attacks). This will also set `LOG_TO_STDOUT` to `false`.
 * `FAIL2BAN_MAXRETRIES` (3):  The number of attempts that fail2ban allows before banning an ip address.
 * `OVPN_TOPOLOGY` (subnet): Network topology mode. Options: `subnet`, `net30`, `p2p`. The `subnet` topology is recommended for modern setups.
 * `OVPN_POOL_PERSIST` (true): If enabled, saves IP address assignments across restarts in `/etc/openvpn/ipp.txt`. Ignored when `OVPN_DUPLICATE_CN` is `true`.
 * `OVPN_DUPLICATE_CN` (false): Allow several simultaneous connections with the same certificate. When `false`, a new connection replaces the existing one.
 * `OVPN_CLIENT_TO_CLIENT` (false): If set to true, allows VPN clients to communicate with each other directly.
 * `OVPN_CLIENT_CONFIG_DIR` (/etc/openvpn/ccd): Directory for client-specific configuration files. This allows you to set specific options (like static IP addresses) for individual clients.
 * `OVPN_REMOTE_ROUTES` (_undefined_): A comma-separated list of routes that OpenVPN will push to the client, in `network_address netmask [gateway]` format. e.g. `172.16.10.0 255.255.255.0,172.17.20.0 255.255.255.0 10.50.50.2`. These routes will be sent to clients using the `push "route"` directive. `OVPN_ROUTES` is accepted as a deprecated alias.
 * `OVPN_LOCAL_ROUTES` (_undefined_): A comma-separated list of routes that will be added to OpenVPN server configuration without pushing to clients, in `network_address netmask [gateway]` format. e.g. `172.16.10.0 255.255.255.0 10.50.50.1,172.17.20.0 255.255.255.0 10.50.50.2`. These routes will be added using the `route` directive.
 * `OVPN_REDIRECT_GATEWAY` (`true` if `OVPN_REMOTE_ROUTES` is empty, otherwise `false`): If set to true, all client traffic will be redirected through the VPN using the `push "redirect-gateway def1"` directive. Set to false to push only specific routes. When `OVPN_NAT=true`, NAT applies to all destinations regardless of this setting.

## Data persistence

Important configuration and data is kept in the container's `/etc/openvpn` directory, so this path should be mounted as a volume or a bind mount.  See the [Docker documentation](https://docs.docker.com/storage/volumes/) for more information.  In the example below, we mount it as a bind mount to a directory on the host.

## Image

The image is published to `ghcr.io/biezax/docker-openvpn` for `linux/amd64` and `linux/arm64`:

* `latest` and `sha-<commit>`: every push to `master`
* `X.Y.Z` and `X.Y`: release tags `vX.Y.Z`

The image is published only after the build and the end-to-end smoke test (`tests/smoke.sh`) pass.

## Launching the OpenVPN daemon container:  

```
docker run \
           --name openvpn \
           --volume /path/on/host:/etc/openvpn \
           --detach=true \
           -p 1194:1194/udp \
           -e "OVPN_SERVER_CN=myserver.mycompany.com" \
           --cap-add=NET_ADMIN \
           ghcr.io/biezax/docker-openvpn:latest
```

* `--cap-add=NET_ADMIN` is necessary; the container needs to create the tunnel device and create iptable rules.

## Managing users

Each user gets an individual certificate, the client configuration embeds it together with the CA and the tls-auth key:

```
docker exec openvpn generate-client-cert john.doe
docker exec openvpn show-client-config john.doe > john.doe.ovpn
docker exec openvpn list-users
docker exec openvpn revoke-cert john.doe
```

`list-users` shows all client certificates with their status (VALID/REVOKED/EXPIRED) and expiry date.
`revoke-cert` rejects new connections with the certificate immediately; an existing connection is dropped at the next TLS renegotiation (within an hour) or when the container is restarted.  After revoking, a new certificate can be issued for the same username.

## Fail2ban administration

You can ban or un-ban IP addresses using the `fail2ban-client` command within the running container. For example, running `docker exec -ti openvpn fail2ban-client set openvpn <banip|unbanip> <IPV4 Address>`. The fail2ban logs are written to `/var/log/fail2ban.log` inside the container; read them with `docker exec openvpn tail -f /var/log/fail2ban.log`.

## Keepalive settings

The OpenVPN server is configured to send a keepalive ping every ten seconds and to restart the client connection if no reply has been received after a minute.  If you set `OVPN_IDLE_TIMEOUT` then the server will kill the client connection after that many seconds, and the client will be configured to _exit_ instead of restart after a minute of failed pings.  For this reason your client can take up to a minute longer than the configured `OVPN_IDLE_TIMEOUT` timeout value before it exits.
