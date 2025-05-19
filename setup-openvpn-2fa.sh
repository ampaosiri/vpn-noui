#!/bin/bash

# Exit immediately if any command fails
set -e

# Clone the repository
echo "Cloning OpenVPN-2FA-GoogleAuth repository..."
git clone https://github.com/ampaosiri/vpn-noui.git

# Change to the repository directory
cd vpn-noui

# Make all .sh scripts executable
echo "Setting execute permissions on all .sh files..."
chmod +x *.sh

# Run the OpenVPN installation script
echo "Running OpenVPN installation script..."
sudo ./openvpn-install.sh

# Search for pam_google_authenticator.so file
echo "Searching for pam_google_authenticator.so..."
find / -name pam_google_authenticator.so 2>/dev/null

# Open PAM template in nano (optional: comment out if automating fully)
echo "Please modify 'openvpn.pam.template' as needed, then save and exit nano."
nano openvpn.pam.template

# Copy PAM template to the correct location
echo "Copying PAM template to /etc/pam.d/openvpn..."
sudo cp openvpn.pam.template /etc/pam.d/openvpn

# Create new OpenVPN user
echo "Running user creation script..."
sudo ./manage.sh batch-create

# Create ZIP package for the client
echo "Creating client ZIP package..."
sudo ./create-zip.sh

echo "Setup completed successfully!"
