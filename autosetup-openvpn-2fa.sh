#!/bin/bash

# Exit immediately if any command fails
set -e

#echo "Cloning OpenVPN-2FA-GoogleAuth repository..."
#git clone https://github.com/ampaosiri/vpn-noui.git
cd vpn-noui

# (Optional) Copy a specific setup script to /root if needed
# sudo cp setup-openvpn-2fa.sh /root/

echo "Setting execute permissions on all .sh files..."
chmod +x *.sh

echo "Running OpenVPN installation script..."
sudo ./openvpn-install.sh

echo "Searching for pam_google_authenticator.so..."
find / -name pam_google_authenticator.so 2>/dev/null

# Optional: Manual edit step (comment out to automate)
# echo "Please modify 'openvpn.pam.template' as needed, then save and exit nano."
# nano openvpn.pam.template

echo "Copying PAM template to /etc/pam.d/openvpn..."
sudo cp openvpn.pam.template /etc/pam.d/openvpn

echo "Running user creation script..."
sudo ./manage.sh batch-create

echo "Creating client ZIP package..."
sudo ./create-zip.sh

echo "Setup completed successfully!"
