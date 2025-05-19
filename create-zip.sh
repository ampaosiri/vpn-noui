#!/bin/bash

# ติดตั้ง zip หากยังไม่ได้ติดตั้ง
install_zip_utility() {
    if ! command -v zip &>/dev/null; then
        echo "zip utility not found. Installing..."
        sudo apt-get update
        sudo apt-get install -y zip
    fi
}

# ฟังก์ชันสร้าง ZIP สำหรับ user หนึ่งคน
create_zip_file() {
    local username="$1"
    local openvpn_base="/opt/openvpn/clients/$username"
    local google_auth_base="/opt/openvpn/google-auth/$username.png"
    local zip_file="/opt/openvpn/clients/${username}.zip"

    # ตรวจสอบว่าโฟลเดอร์ user มีอยู่จริงหรือไม่
    if [ ! -d "$openvpn_base" ]; then
        echo "Client directory not found: $openvpn_base"
        return
    fi

    # สร้าง zip ที่รวมทั้งไฟล์ config (.ovpn) และ QR code (.png)
    zip -j "$zip_file" "$openvpn_base"/* "$google_auth_base" 2>/dev/null

    if [ $? -eq 0 ]; then
        echo "✅ Created: $zip_file"
    else
        echo "❌ Failed: $zip_file"
    fi
}

# เริ่มต้นกระบวนการ
install_zip_utility

echo "📦 Creating zip files for all OpenVPN users..."

# วนลูปในทุกโฟลเดอร์ user
for dir in /opt/openvpn/clients/*/; do
    username=$(basename "$dir")
    create_zip_file "$username"
done
