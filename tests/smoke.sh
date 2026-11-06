#!/bin/bash
# End-to-end check: server start, client connection, revocation, PKI kept on restart.
# Usage: tests/smoke.sh IMAGE
set -euo pipefail

IMAGE=${1:?usage: $0 IMAGE}
P="ovpn-smoke-$$"
TMP=$(mktemp -d)

cleanup() {
  docker rm -f "$P-srv" "$P-cli" >/dev/null 2>&1 || true
  docker network rm "$P-net" >/dev/null 2>&1 || true
  docker volume rm "$P-vol" >/dev/null 2>&1 || true
  rm -rf "$TMP"
}
trap cleanup EXIT

fail() {
  echo "FAIL: $*" >&2
  for c in "$P-srv" "$P-cli"; do
    echo "--- $c" >&2
    docker logs --tail 40 "$c" 2>&1 >&2 || true
  done
  exit 1
}

# wait_log CONTAINER PATTERN SECONDS
wait_log() {
  for _ in $(seq "$3"); do
    docker logs "$1" 2>&1 | grep -q "$2" && return 0
    sleep 1
  done
  return 1
}

start_server() {
  docker run -d --name "$P-srv" --network "$P-net" --cap-add NET_ADMIN --device /dev/net/tun \
    -v "$P-vol:/etc/openvpn" -e OVPN_SERVER_CN="$P-srv" -e OVPN_EXTRA="reneg-sec 20" "$IMAGE" >/dev/null
  wait_log "$P-srv" 'Initialization Sequence Completed' 60 || fail "server did not start"
}

start_client() {
  docker rm -f "$P-cli" >/dev/null 2>&1 || true
  docker run -d --name "$P-cli" --network "$P-net" --cap-add NET_ADMIN --device /dev/net/tun \
    -v "$TMP:/c:ro" --entrypoint openvpn "$IMAGE" --config "/c/$1.ovpn" >/dev/null
}

docker network create "$P-net" >/dev/null
start_server

docker exec "$P-srv" generate-client-cert alice >/dev/null
docker exec "$P-srv" show-client-config alice >"$TMP/alice.ovpn"
start_client alice
wait_log "$P-cli" 'Initialization Sequence Completed' 30 || fail "client did not connect"
echo "ok: client connected"

docker exec "$P-srv" revoke-cert alice >/dev/null
wait_log "$P-srv" 'certificate revoked: CN=alice' 60 || fail "connected client was not dropped after revocation"
echo "ok: revoked client dropped at renegotiation"

start_client alice
if wait_log "$P-cli" 'Initialization Sequence Completed' 15; then
  fail "revoked client reconnected"
fi
echo "ok: revoked client rejected"

ca=$(docker exec "$P-srv" sha256sum /etc/openvpn/pki/ca.crt)
docker rm -f "$P-srv" >/dev/null
start_server
[ "$(docker exec "$P-srv" sha256sum /etc/openvpn/pki/ca.crt)" == "$ca" ] || fail "CA changed after restart"
docker exec "$P-srv" generate-client-cert bob >/dev/null
docker exec "$P-srv" show-client-config bob >"$TMP/bob.ovpn"
start_client bob
wait_log "$P-cli" 'Initialization Sequence Completed' 30 || fail "client did not connect after restart"
echo "ok: PKI kept across restart"

users=$(docker exec "$P-srv" list-users)
{ grep -q '^alice  *REVOKED' <<<"$users" && grep -q '^bob  *VALID' <<<"$users"; } || fail "unexpected list-users output: $users"
echo "ok: list-users"
echo "PASS"
