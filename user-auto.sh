#!/bin/bash

echo "Running user creation script..."
sudo ./manage-user.sh create-batch
#sudo ./manage.sh batch-create

echo "Creating client ZIP package..."
sudo ./create-zip.sh

echo "Setup completed successfully!"
