#Create the VPN tunnel interface
mkdir -p /dev/net
if [ ! -c /dev/net/tun ]; then
  mknod /dev/net/tun c 10 200
fi

# "network netmask [gateway]" -> "network/prefix"
to_cidr() {
  local net mask
  read -r net mask _ <<<"$1"
  echo "${net}/$(ipcalc -nb "$net" "$mask" | awk '/^Netmask/ { print $NF }')"
}

# Masquerade VPN traffic to all destinations
masquerade() {
  local rule=(POSTROUTING -s "$ovpn_net" -o "$nat_device" -j MASQUERADE)
  echo -n "iptables: masquerade from $ovpn_net to everywhere via $nat_device: "
  if iptables -t nat -C "${rule[@]}" >/dev/null 2>&1; then
    echo "rule already present"
  else
    echo "adding rule"
    iptables -t nat -A "${rule[@]}"
  fi
}

ovpn_net=$(to_cidr "$OVPN_NETWORK")
nat_device=$(awk '$2 == "00000000" { print $1; exit }' /proc/net/route)

routes_config="/tmp/routes_config.txt"
: >"$routes_config"

if [ "${OVPN_ROUTES}x" != "x" ]; then
  echo "routes: WARNING: OVPN_ROUTES is deprecated, use OVPN_REMOTE_ROUTES"
fi

IFS=',' read -r -a remote_routes <<<"$OVPN_REMOTE_ROUTES"
IFS=',' read -r -a local_routes <<<"$OVPN_LOCAL_ROUTES"

# Routes pushed to clients
for this_route in "${remote_routes[@]}"; do
  echo "routes: pushing route $this_route to clients"
  echo "push \"route $this_route\"" >>"$routes_config"
done

# Server-side routes without push
for this_route in "${local_routes[@]}"; do
  echo "routes: adding server route $this_route"
  echo "route $this_route" >>"$routes_config"
done

if [ "$OVPN_REDIRECT_GATEWAY" == "true" ]; then
  echo "routes: redirecting all client traffic through the VPN"
  echo "push \"redirect-gateway def1\"" >>"$routes_config"
fi

if [ "$OVPN_NAT" == "true" ]; then
  masquerade
fi

# Append extra iptables rules from a file if specified
if [ "${IPTABLES_EXTRA_FILE}x" != "x" ]; then
  if [ -f "$IPTABLES_EXTRA_FILE" ]; then
    echo "IPTABLES_EXTRA_FILE was set, appending iptables rules from $IPTABLES_EXTRA_FILE"
    iptables-restore -nv "$IPTABLES_EXTRA_FILE"
  else
    echo "IPTABLES_EXTRA_FILE was set but the specified file $IPTABLES_EXTRA_FILE cannot be found!"
  fi
fi
