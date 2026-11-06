source /opt/configuration/functions.sh

abort=0

show_error () {
 echo "**"
 echo
 echo " $1 is missing.  Please set it as an environmental variable when launching the container:"
 echo "  -e \"$1=your_value\""
 echo
 echo "**"
 echo
 abort=1
}

if [ "${OVPN_SERVER_CN}x" == "x" ]; then show_error OVPN_SERVER_CN ; fi

if [ "$abort" == "1" ]; then exit 1 ; fi

export OPENVPN_DIR="/etc/openvpn"
export CONFIGFILES="/opt/configuration"
export EASYRSA_DIR="/opt/easyrsa"
export PKI_DIR="${OPENVPN_DIR}/pki"
export LOG_DIR="${OPENVPN_DIR}/logs"
if [ ! -d "$LOG_DIR" ]; then
 mkdir -p $LOG_DIR
fi

default_tls_ciphers="TLS-ECDHE-ECDSA-WITH-CHACHA20-POLY1305-SHA256:TLS-ECDHE-RSA-WITH-CHACHA20-POLY1305-SHA256:TLS-ECDHE-ECDSA-WITH-AES-128-GCM-SHA256:TLS-ECDHE-RSA-WITH-AES-128-GCM-SHA256"
default_tls_ciphersuites="TLS-AES-256-GCM-SHA384:TLS-CHACHA20-POLY1305-SHA256:TLS-AES-128-GCM-SHA256:TLS-AES-128-CCM-8-SHA256:TLS-AES-128-CCM-SHA256"

if [ "${OVPN_TLS_CIPHERS}x" == "x" ];             then export OVPN_TLS_CIPHERS=$default_tls_ciphers;                fi
if [ "${OVPN_TLS_CIPHERSUITES}x" == "x" ];        then export OVPN_TLS_CIPHERSUITES=$default_tls_ciphersuites;      fi
if [ "${OVPN_PORT}x" == "x" ];                    then export OVPN_PORT="1194";                                     fi
if [ "${OVPN_PROTOCOL}x" == "x" ];                then export OVPN_PROTOCOL="udp";                                  fi
if [ "${OVPN_INTERFACE_NAME}x" == "x" ];          then export OVPN_INTERFACE_NAME="tun";                            fi
if [ "${OVPN_NETWORK}x" == "x" ];                 then export OVPN_NETWORK="10.50.50.0 255.255.255.0";              fi
# Deprecated alias kept for upgrades from the original image
if [ "${OVPN_REMOTE_ROUTES}x" == "x" ] && [ "${OVPN_ROUTES}x" != "x" ]; then export OVPN_REMOTE_ROUTES="$OVPN_ROUTES"; fi
if [ "${OVPN_REDIRECT_GATEWAY}x" == "x" ]; then
 if [ "${OVPN_REMOTE_ROUTES}x" == "x" ]; then export OVPN_REDIRECT_GATEWAY="true"; else export OVPN_REDIRECT_GATEWAY="false"; fi
fi
if [ "${OVPN_VERBOSITY}x" == "x" ];               then export OVPN_VERBOSITY="3";                                   fi
if [ "${OVPN_NAT}x" == "x" ];                     then export OVPN_NAT="true";                                      fi
if [ "${OVPN_REGISTER_DNS}x" == "x" ];            then export OVPN_REGISTER_DNS="false";                            fi
if [ "${REGENERATE_CERTS}x" == "x" ];             then export REGENERATE_CERTS="false";                             fi
if [ "${CLIENT_CERT_EXPIRE}x" == "x" ];           then export CLIENT_CERT_EXPIRE="825";                             fi
if [ "${OVPN_MANAGEMENT_ENABLE}x" == "x" ];       then export OVPN_MANAGEMENT_ENABLE="false";                       fi
if [ "${OVPN_MANAGEMENT_NOAUTH}x" == "x" ];       then export OVPN_MANAGEMENT_NOAUTH="false";                       fi
if [ "${OVPN_MANAGEMENT_ADDRESS}x" == "x" ];      then export OVPN_MANAGEMENT_ADDRESS="127.0.0.1";                  fi
if [ "${OVPN_DEFAULT_SERVER}x" == "x" ];          then export OVPN_DEFAULT_SERVER="true";                           fi
if [ "${DEBUG}x" == "x" ];                        then export DEBUG="false";                                        fi
if [ "${LOG_TO_STDOUT}x" == "x" ];                then export LOG_TO_STDOUT="true";                                 fi
if [ "${KEY_LENGTH}x" == "x" ];                   then export KEY_LENGTH="2048";                                    fi
if [ "${FAIL2BAN_ENABLED}x" == "x" ];             then export FAIL2BAN_ENABLED="false";                             fi
if [ "${FAIL2BAN_MAXRETRIES}x" == "x" ];          then export FAIL2BAN_MAXRETRIES="3";                              fi
if [ "${OVPN_TOPOLOGY}x" == "x" ];                then export OVPN_TOPOLOGY="subnet";                               fi
if [ "${OVPN_POOL_PERSIST}x" == "x" ];            then export OVPN_POOL_PERSIST="true";                             fi
if [ "${OVPN_CLIENT_TO_CLIENT}x" == "x" ];        then export OVPN_CLIENT_TO_CLIENT="false";                        fi
if [ "${OVPN_CLIENT_CONFIG_DIR}x" == "x" ];       then export OVPN_CLIENT_CONFIG_DIR="${OPENVPN_DIR}/ccd";          fi
if [ "${OVPN_DUPLICATE_CN}x" == "x" ];            then export OVPN_DUPLICATE_CN="false";                            fi
if [ "${OVPN_CLIENT_CONFIG_DIR}x" != "x" ]; then
    mkdir -p "${OVPN_CLIENT_CONFIG_DIR}"
fi
if [ "$FAIL2BAN_ENABLED" == "true" ];             then export LOG_TO_STDOUT="false";                                fi
if [ "$LOG_TO_STDOUT" == "true" ]; then
 LOG_FILE="/proc/1/fd/1"
else
 LOG_FILE="${LOG_DIR}/openvpn.log"
 touch $LOG_FILE
fi
