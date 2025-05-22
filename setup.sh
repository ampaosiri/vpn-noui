#!/bin/bash

set -e

echo "🔧 เริ่มต้นตั้งค่า OpenVPN Droplet ด้วย Terraform"
echo "----------------------------------------------"

# ตรวจสอบ doctl
if ! command -v doctl &> /dev/null; then
  echo "❌ ไม่พบคำสั่ง doctl"
  echo "ℹ️  ติดตั้งด้วยคำสั่ง: sudo snap install doctl"
  exit 1
fi

# รับ API Token
read -p "🔐 กรุณาใส่ DigitalOcean API Token: " do_token
export DIGITALOCEAN_ACCESS_TOKEN="$do_token"

# ตรวจสอบ login doctl
echo "✅ กำลังตรวจสอบ SSH Keys ผ่าน doctl..."
if ! doctl auth init --access-token "$do_token" &>/dev/null; then
  echo "❌ ไม่สามารถเข้าสู่ระบบ DigitalOcean ด้วย API Token นี้"
  exit 1
fi

# ดึง SSH Keys
mapfile -t ssh_keys < <(doctl compute ssh-key list --format "ID,Name" --no-header)
if [ ${#ssh_keys[@]} -eq 0 ]; then
  echo "❌ ไม่พบ SSH Key ในบัญชี DigitalOcean ของคุณ"
  exit 1
fi

echo "🔑 เลือก SSH Key:"
select ssh_entry in "${ssh_keys[@]}"; do
  if [[ -n "$ssh_entry" ]]; then
    ssh_key_id=$(echo "$ssh_entry" | awk -F, '{print $1}')
    break
  else
    echo "❌ กรุณาเลือกหมายเลขที่ถูกต้อง"
  fi
done

# เลือกชื่อ Droplet
read -p "📛 ชื่อ Droplet (default: Openvpn-NOUI): " droplet_name
droplet_name=${droplet_name:-Openvpn-NOUI}

# เลือก region
read -p "🌍 Region (default: sgp1): " region
region=${region:-sgp1}

# ใส่ Tag
read -p "🏷️  ใส่ Tag (คั่นด้วย ,): " tags_input
IFS=',' read -ra tag_array <<< "$tags_input"
tags_formatted=$(printf "\"%s\", " "${tag_array[@]}")
tags="[${tags_formatted%, }]"

# เมนูขนาด Droplet
echo "🖥️  เลือกขนาด Droplet:"
sizes=(
  "s-1vcpu-1gb"
  "s-1vcpu-2gb"
  "s-2vcpu-2gb"
  "s-2vcpu-4gb"
  "s-4vcpu-8gb"
)
select size in "${sizes[@]}"; do
  if [[ -n "$size" ]]; then
    echo "✅ คุณเลือกขนาด: $size"
    break
  else
    echo "❌ กรุณาเลือกหมายเลขที่ถูกต้อง"
  fi
done

# เขียน terraform.tfvars
cat > terraform.tfvars <<EOF
do_token     = "$do_token"
ssh_key_id   = "$ssh_key_id"
droplet_name = "$droplet_name"
region       = "$region"
droplet_size = "$size"
tags         = $tags
EOF

echo "✅ เขียนไฟล์ terraform.tfvars สำเร็จ"

# เริ่ม Terraform
echo "🚀 กำลังรัน terraform init และ apply..."
terraform init
terraform apply
