#!/bin/bash

# Function to print characters with delay
print_with_delay() {
    text=$1
    delay=$2
    for ((i = 0; i < ${#text}; i++)); do
        echo -n "${text:$i:1}"
        sleep $delay
    done
}

# Introduction animation
echo ""
echo ""
print_with_delay "s" 0.1
print_with_delay "i" 0.1
print_with_delay "n" 0.1
print_with_delay "g" 0.1
print_with_delay "-" 0.1
print_with_delay "R" 0.1
print_with_delay "E" 0.1
print_with_delay "A" 0.1
print_with_delay "L" 0.1
print_with_delay "I" 0.1
print_with_delay "T" 0.1
print_with_delay "Y" 0.1
print_with_delay "-" 0.1
print_with_delay "b" 0.1
print_with_delay "o" 0.1
print_with_delay "x" 0.1
print_with_delay " " 0.1
print_with_delay "b" 0.1
print_with_delay "y" 0.1
print_with_delay " " 0.1
print_with_delay "D" 0.1
print_with_delay "E" 0.1
print_with_delay "A" 0.1
print_with_delay "T" 0.1
print_with_delay "H" 0.1
print_with_delay "L" 0.1
print_with_delay "I" 0.1
print_with_delay "N" 0.1
print_with_delay "E" 0.1
print_with_delay " " 0.1
print_with_delay "|" 0.1
print_with_delay " " 0.1
print_with_delay "n" 0.1
print_with_delay "a" 0.1
print_with_delay "m" 0.1
print_with_delay "e" 0.1
print_with_delay "l" 0.1
print_with_delay "e" 0.1
print_with_delay "s" 0.1
print_with_delay " " 0.1
print_with_delay "g" 0.1
print_with_delay "h" 0.1
print_with_delay "o" 0.1
print_with_delay "u" 0.1
print_with_delay "l" 0.1
print_with_delay ""
echo ""
echo ""


# Check if jq is installed, and install it if not
if ! command -v jq &> /dev/null; then
    echo "jq is not installed. Installing..."
    if [ -n "$(command -v apt)" ]; then
        apt update
        apt install -y jq
    elif [ -n "$(command -v yum)" ]; then
        yum install -y epel-release
        yum install -y jq
    elif [ -n "$(command -v dnf)" ]; then
        dnf install -y jq
    else
        echo "Cannot install jq. Please install jq manually and rerun the script."
        exit 1
    fi
fi

# Download and install sing-box binary
echo "Downloading and installing sing-box binary..."
curl -sLo /root/sb https://github.com/SagerNet/sing-box/releases/download/v1.3-beta11/sing-box-1.3-beta11-linux-amd64.tar.gz && tar -xzf /root/sb && cp -f /root/sing-box-*/sing-box /root && rm -r /root/sb /root/sing-box-* && chown root:root /root/sing-box && chmod +x /root/sing-box
echo "sing-box installation complete."
echo

# Generate key pair
echo "Generating key pair..."
key_pair=$(/root/sing-box generate reality-keypair)
echo "Key pair generation complete."
echo

# Extract private key and public key
private_key=$(echo "$key_pair" | awk '/PrivateKey/ {print $2}' | tr -d '"')
public_key=$(echo "$key_pair" | awk '/PublicKey/ {print $2}' | tr -d '"')

# Generate necessary values
uuid=$(/root/sing-box generate uuid)
short_id=$(/root/sing-box generate rand --hex 8)

# Ask for listen port
read -p "Enter desired listen port (default: 443): " listen_port
listen_port=${listen_port:-443}

# Ask for server name (sni)
read -p "Enter server name/SNI (default: telewebion.com): " server_name
server_name=${server_name:-telewebion.com}

# Retrieve the server IP address
server_ip=$(curl -s https://api.ipify.org)

# Create reality.json using jq
jq -n --arg listen_port "$listen_port" --arg server_name "$server_name" --arg private_key "$private_key" --arg short_id "$short_id" --arg uuid "$uuid" --arg server_ip "$server_ip" '{
  "log": {
    "level": "info",
    "timestamp": true
  },
  "inbounds": [
    {
      "type": "vless",
      "tag": "vless-in",
      "listen": "::",
      "listen_port": ($listen_port | tonumber),
      "sniff": true,
      "sniff_override_destination": true,
      "domain_strategy": "ipv4_only",
      "users": [
        {
          "uuid": $uuid,
          "flow": "xtls-rprx-vision"
        }
      ],
      "tls": {
        "enabled": true,
        "server_name": $server_name,
          "reality": {
          "enabled": true,
          "handshake": {
            "server": $server_name,
            "server_port": 443
          },
          "private_key": $private_key,
          "short_id": [$short_id]
        }
      }
    }
  ],
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct"
    },
    {
      "type": "block",
      "tag": "block"
    }
  ]
}' > /root/reality.json

# Create sing-box.service
cat > /etc/systemd/system/sing-box.service <<EOF
[Unit]
After=network.target nss-lookup.target

[Service]
User=root
WorkingDirectory=/root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
ExecStart=/root/sing-box run -c /root/reality.json
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
RestartSec=10
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
EOF

# Check configuration and start the service
if /root/sing-box check -c /root/reality.json; then
    echo "Configuration checked successfully. Starting sing-box service..."
    systemctl daemon-reload
    systemctl enable sing-box
    systemctl start sing-box
    systemctl restart sing-box

# Generate the link

    server_link="vless://$uuid@$server_ip:$listen_port?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$server_name&fp=chrome&pbk=$public_key&sid=$short_id&type=tcp&headerType=none#SING-BOX-TCP"

    # Print the server details
    echo
    echo "Server IP: $server_ip"
    echo "Listen Port: $listen_port"
    echo "Server Name: $server_name"
    echo "Public Key: $public_key"
    echo "Short ID: $short_id"
    echo "UUID: $uuid"
    echo ""
    echo ""
    echo ""
    echo "Here is the link for v2rayN and v2rayNG :"
    echo ""
    echo "$server_link"
else
    echo "Error in configuration. Aborting."
fi

