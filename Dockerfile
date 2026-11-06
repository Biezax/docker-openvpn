FROM ubuntu:26.04

LABEL org.opencontainers.image.authors="s.rossovskii@gmail.com"

# OpenVPN comes from the upstream repository (stable channel), Ubuntu lags behind
ADD https://swupdate.openvpn.net/repos/repo-public.gpg /etc/apt/keyrings/openvpn-repo-public.asc

RUN chmod 644 /etc/apt/keyrings/openvpn-repo-public.asc && \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ca-certificates && \
    . /etc/os-release && \
    echo "deb [signed-by=/etc/apt/keyrings/openvpn-repo-public.asc] https://build.openvpn.net/debian/openvpn/stable ${VERSION_CODENAME} main" \
        > /etc/apt/sources.list.d/openvpn-aptrepo.list && \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive \
    apt-get install -y --no-install-recommends \
            easy-rsa \
            fail2ban \
            ipcalc \
            iptables \
            openssl \
            openvpn && \
    rm -rf /var/lib/apt/lists/* && \
    mkdir /opt/easyrsa && \
    cp -rp /usr/share/easy-rsa/easyrsa /usr/share/easy-rsa/openssl-easyrsa.cnf /usr/share/easy-rsa/x509-types /opt/easyrsa/

EXPOSE 1194/udp

COPY ./files/bin /usr/local/bin
RUN chmod a+x /usr/local/bin/*
COPY ./files/configuration /opt/configuration
COPY ./files/easyrsa/pki_vars /opt/easyrsa/

# Use a volume for data persistence
VOLUME /etc/openvpn

CMD ["/usr/local/bin/entrypoint"]
