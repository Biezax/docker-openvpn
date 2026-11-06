# Never recreate an existing CA unless explicitly requested
if [ "$REGENERATE_CERTS" == "true" ] || {
 [ ! -f "$PKI_DIR/ca.crt" ] && [ ! -f "$PKI_DIR/private/ca.key" ] &&
 [ ! -s "$PKI_DIR/index.txt" ] &&
 [ -z "$(find "$PKI_DIR/issued" -type f -print -quit 2>/dev/null)" ];
}; then
 if [ "$REGENERATE_CERTS" == "true" ]; then
  echo "easyrsa: WARNING: REGENERATE_CERTS=true, recreating the whole PKI."
  echo "easyrsa: WARNING: all issued certificates and client configurations become invalid."
  echo "easyrsa: WARNING: unset REGENERATE_CERTS, otherwise the PKI is recreated on every start."
 fi
 echo "easyrsa: creating CA"
 easyrsa init-pki
 easyrsa --req-cn="$OVPN_SERVER_CN" build-ca nopass
elif [ ! -f "$PKI_DIR/ca.crt" ] || [ ! -f "$PKI_DIR/private/ca.key" ]; then
 echo "easyrsa: ERROR: incomplete CA: ca.crt or private/ca.key is missing; restore the missing file. PKI left unchanged." >&2
 exit 1
fi

# easy-rsa 3.1 copied its OpenSSL template into the PKI; newer releases reject that copy
# and use the template shipped with the image instead
rm -f "$PKI_DIR/openssl-easyrsa.cnf"

if [ ! -f "$PKI_DIR/ta.key" ]; then
 echo "openvpn: creating tls-auth key"
 openvpn --genkey secret "$PKI_DIR/ta.key"
fi

if [ ! -f "$PKI_DIR/issued/server.crt" ]; then
 echo "easyrsa: creating server certificate"
 # Leftovers of an interrupted run would make easyrsa refuse to continue
 rm -f "$PKI_DIR/reqs/server.req" "$PKI_DIR/private/server.key"
 easyrsa build-server-full server nopass
fi

# Refresh on every start so the CRL never expires
echo "easyrsa: updating CRL"
easyrsa gen-crl
install_crl
