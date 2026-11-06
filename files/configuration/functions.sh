# Shared helpers, sourced from set_defaults.sh

easyrsa() {
  (
    . "$EASYRSA_DIR/pki_vars"
    "$EASYRSA_DIR/easyrsa" "$@"
  )
}

# OpenVPN re-reads the CRL as an unprivileged user, so it needs a readable copy
install_crl() {
  install -m 644 "$PKI_DIR/crl.pem" "$OPENVPN_DIR/crl.pem"
}

# Client certificate names must be safe file names and not clash with the CA or server certificates
validate_client_name() {
  if [[ -z "$1" || "$1" == */* || "$1" == .* || "$1" == -* ]]; then
    echo "Error: invalid username '$1'." >&2
    return 1
  fi
  if [ "$1" == "server" ] || [ "$1" == "ca" ] || [ "$1" == "$OVPN_SERVER_CN" ]; then
    echo "Error: '$1' is a reserved name." >&2
    return 1
  fi
}
