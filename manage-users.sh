#!/bin/bash

# Configuration
export EASYRSA_PKI="/etc/openvpn/easy-rsa/pki"
ACTION=$1
CLIENT=$2
HOST=$(hostname)
CLIENTDIR="/opt/openvpn/clients"
LOG_FILE="/var/log/vpn-management.log"

# Colors
R="\e[0;91m"
G="\e[0;92m"
W="\e[0;97m"
B="\e[1m"
C="\e[0m"

# Logging function
function log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "$LOG_FILE"
}

# Validate username format
function validate_username() {
    local username=$1
    [[ "$username" =~ ^[a-zA-Z0-9_-]+$ ]] || { log "Invalid username format: $username"; return 1; }
    grep -q -E "/CN=$username$" "$EASYRSA_PKI/index.txt" && { log "Username already exists: $username"; return 1; }
    return 0
}

# Email profile function
function emailProfile() {
    local CLIENT=$1
    local PASSWORD=$2
    
    log "Sending VPN profile to $CLIENT"
    hostlist=$(cat /etc/hosts | grep -v "#" | grep -v "localhost" | grep -v "127.0.0.1" | grep -v -e "^$")
    
    content="""########## OpenVPN connection profile (${HOST}) ###################

Use the attached VPN profile to connect using Tunnelblick or OpenVPN Connect.

VPN username: ${CLIENT}
VPN password: ${PASSWORD}

Use attached QR code to register your 2FA with Authy.

If DNS is not working, you can use /etc/hosts list below:
----------------------------------------
${hostlist}
"""
    
    echo "${content}" | mailx -s "Your OpenVPN profile" \
      -a "${CLIENTDIR}/${CLIENT}/${CLIENT}.ovpn" \
      -a "/opt/openvpn/google-auth/${CLIENT}.png" \
      -r "Devops<devops@company.com>" \
      "${CLIENT}@company.com" || { log "Failed to email profile to $CLIENT"; return 1; }
}

# Create new client
function newClient() {
    local NON_INTERACTIVE=${3:-false}
    
    if [[ -z "$CLIENT" ]]; then
        if $NON_INTERACTIVE; then
            log "Client name is required in non-interactive mode"
            return 1
        fi
        
        echo ""
        echo "Tell me a name for the client."
        echo "The name must consist of alphanumeric characters. It may also include an underscore or dash."
        
        until [[ $CLIENT =~ ^[a-zA-Z0-9_-]+$ ]]; do
            read -rp "Client name: " -e CLIENT
        done
    fi

    if ! validate_username "$CLIENT"; then
        return 1
    fi

    local PASS=1
    if ! $NON_INTERACTIVE; then
        echo ""
        echo "Do you want to protect the configuration file with a password?"
        echo "1) Add a passwordless client"
        echo "2) Use a password for the client"

        until [[ $PASS =~ ^[1-2]$ ]]; do
            read -rp "Select an option [1-2]: " -e -i 1 PASS
        done
    fi

    # Create system user
    if ! useradd -M -s /usr/sbin/nologin "$CLIENT"; then
        log "Failed to create system user: $CLIENT"
        return 1
    fi

    # Generate passwords
    local RANDOM_PASSWORD=$(openssl rand -base64 12)
    echo "$CLIENT:$RANDOM_PASSWORD" | chpasswd
    mkdir -p "$CLIENTDIR/$CLIENT"
    local FILE_PATH="$CLIENTDIR/$CLIENT/pass"

    # Generate client certs
    if [[ $PASS == "2" ]]; then
        local PRIVATE_KEY_PASSWORD=$(openssl rand -base64 12)
        if ! /etc/openvpn/easy-rsa/easyrsa --batch --passout=pass:"$PRIVATE_KEY_PASSWORD" build-client-full "$CLIENT"; then
            log "Failed to generate client certificate for $CLIENT"
            return 1
        fi
        echo "private key pass: $PRIVATE_KEY_PASSWORD" > "$FILE_PATH"
        echo "user password: $RANDOM_PASSWORD" >> "$FILE_PATH"
    else
        if ! /etc/openvpn/easy-rsa/easyrsa --batch build-client-full "$CLIENT" nopass; then
            log "Failed to generate client certificate for $CLIENT"
            return 1
        fi
        echo "user password: $RANDOM_PASSWORD" > "$FILE_PATH"
    fi

    # Create OVPN file
    chmod 600 "$FILE_PATH"
    cp /etc/openvpn/client-template.txt "$CLIENTDIR/$CLIENT/${CLIENT}.ovpn"
    {
        echo 'static-challenge "Enter OTP: " 1'
        echo 'auth-user-pass'
        echo "<ca>"
        cat "$EASYRSA_PKI/ca.crt"
        echo "</ca>"
        echo "<cert>"
        awk '/BEGIN/,/END CERTIFICATE/' "$EASYRSA_PKI/issued/$CLIENT.crt"
        echo "</cert>"
        echo "<key>"
        cat "$EASYRSA_PKI/private/$CLIENT.key"
        echo "</key>"
        if grep -qs "^tls-crypt" /etc/openvpn/server.conf; then
            echo "<tls-crypt>"
            cat /etc/openvpn/tls-crypt.key
            echo "</tls-crypt>"
        elif grep -qs "^tls-auth" /etc/openvpn/server.conf; then
            echo "key-direction 1"
            echo "<tls-auth>"
            cat "/etc/openvpn/tls-auth.key"
            echo "</tls-auth>"
        fi
    } >> "$CLIENTDIR/$CLIENT/${CLIENT}.ovpn"

    # Generate Google Authenticator
    local GA_DIR="/opt/openvpn/google-auth"
    mkdir -p "$GA_DIR"
    local GA_FILE="$GA_DIR/$CLIENT"
    local QR_CODE="$GA_DIR/$CLIENT.png"

    if ! google-authenticator -t -d -f -r 3 -R 30 -W -C -s "$GA_FILE"; then
        log "Error generating Google Authenticator for $CLIENT"
        return 1
    fi

    local secret=$(head -n 1 "$GA_FILE")
    if ! qrencode -t PNG -o "$QR_CODE" "otpauth://totp/$CLIENT@$HOST?secret=$secret&issuer=openvpn"; then
        log "Error generating QR code for $CLIENT"
        return 1
    fi

    chmod 600 "$GA_FILE" "$QR_CODE"
    log "Successfully created client: $CLIENT"
    return 0
}

# Batch create clients
function batchCreateClients() {
    local users=()
    
    # Read from arguments or stdin
    if [[ $# -gt 0 ]]; then
        users=("$@")
    else
        echo "Enter usernames (one per line). End input with an empty line:"
        while true; do
            read -rp "Username: " user
            [[ -z "$user" ]] && break
            users+=("$user")
        done
    fi

    local error_count=0
    for u in "${users[@]}"; do
        if ! validate_username "$u"; then
            ((error_count++))
            continue
        fi
        
        log "Creating user: $u"
        if ! newClient "$u" "" true; then
            ((error_count++))
        fi
    done

    if [[ $error_count -gt 0 ]]; then
        log "Failed to create $error_count users"
        return 1
    fi
    
    return 0
}

# Revoke client
function revokeClient() {
    [[ -z "$CLIENT" ]] && { log "Client name required for revocation"; return 1; }
    
    log "Revoking client: $CLIENT"
    cd /etc/openvpn/easy-rsa/ || return 1
    
    ./easyrsa --batch revoke "${CLIENT}" || { log "Failed to revoke certificate"; return 1; }
    EASYRSA_CRL_DAYS=3650 ./easyrsa gen-crl || { log "Failed to generate CRL"; return 1; }
    
    rm -f "pki/reqs/${CLIENT}.req*" "pki/private/${CLIENT}.key*" "pki/issued/${CLIENT}.crt*"
    rm -f /etc/openvpn/crl.pem
    cp /etc/openvpn/easy-rsa/pki/crl.pem /etc/openvpn/crl.pem
    chmod 644 /etc/openvpn/crl.pem
    sed -i "/CN=${CLIENT}$/d" /etc/openvpn/easy-rsa/pki/index.txt
    
    if id "${CLIENT}" >/dev/null 2>&1; then
        userdel -r -f "${CLIENT}" || { log "Failed to delete system user"; return 1; }
    fi
    
    rm -rf "${CLIENTDIR:?}/${CLIENT:?}"
    log "Successfully revoked access for $CLIENT"
    return 0
}

# Main script execution
if [[ $# -lt 1 ]]; then 
    echo -e "${W}Usage:${C}"
    echo -e "  ${W}./manage.sh create [username]${C}"
    echo -e "  ${W}./manage.sh revoke <username>${C}"
    echo -e "  ${W}./manage.sh status${C}"
    echo -e "  ${W}./manage.sh send <username>${C}"
    echo -e "  ${W}./manage.sh batch-create [username1 username2 ...]${C}"
    exit 1
fi

case "${ACTION}" in
    "batch-create")
        shift
        batchCreateClients "$@"
        ;;
    "create")
        newClient "$CLIENT" "" false
        ;;
    "revoke")
        revokeClient
        ;;
    "status")
        grep "^V" "$EASYRSA_PKI/index.txt" | grep -v "server_"
        ;;
    "send")
        [[ -z "${CLIENT}" ]] && { echo -e "${R}Provide a username${C}"; exit 1; }
        PW=$(cat "${CLIENTDIR}/${CLIENT}/pass" 2>/dev/null) || { echo -e "${R}User doesn't exist${C}"; exit 1; }
        emailProfile "${CLIENT}" "${PW}" || exit 1
        echo -e "${G}Email sent to ${CLIENT}${C}"
        ;;
    *)
        echo -e "${R}Invalid action: ${ACTION}${C}"
        exit 1
        ;;
esac

exit $?
