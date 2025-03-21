#!/bin/bash

# Deployment script for the Booking component
# This script sets up the Booking website on a new system

# Check if script is running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root (sudo)"
    exit 1
fi

echo "=== Booking Component Deployment ==="
echo "This script sets up the Booking website"

# Define variables
BOOKING_DIR="/var/www/html/booking"
DB_NAME="computer_booking"
DB_USER="bookinguser"
DB_PASS="$(openssl rand -base64 12)"  # Generates a random password

# 1. Install dependencies
echo "1. Installing dependencies..."
apt-get update
apt-get install -y apache2 php php-mysql mysql-server python3 python3-pip

# 2. Install Python dependencies
echo "2. Installing Python dependencies..."
pip3 install flask flask-cors mysql-connector-python

# 3. Create directory for the Booking component
echo "3. Creating directory structure..."
mkdir -p $BOOKING_DIR

# 4. Copy files
echo "4. Copying files..."
cp -r Booking/* $BOOKING_DIR/
chmod +x $BOOKING_DIR/deploy_booking.sh

# 5. Set up MySQL database
echo "5. Setting up database..."
mysql -e "CREATE DATABASE IF NOT EXISTS $DB_NAME;"
mysql -e "CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';"
mysql -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"

# 6. Create tables
echo "6. Creating database tables..."
mysql $DB_NAME << EOF
CREATE TABLE IF NOT EXISTS computers (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(50) NOT NULL,
    status VARCHAR(20) DEFAULT 'available'
);

CREATE TABLE IF NOT EXISTS bookings (
    id INT AUTO_INCREMENT PRIMARY KEY,
    computer_name VARCHAR(50) NOT NULL,
    user VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL,
    start_time DATETIME NOT NULL,
    end_time DATETIME NOT NULL,
    status VARCHAR(20) DEFAULT 'booked',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert example computers
INSERT INTO computers (name, status) VALUES 
('PC-1', 'available'),
('PC-2', 'available'),
('PC-3', 'available'),
('PC-4', 'available'),
('PC-5', 'available');
EOF

# 7. Update configuration file for the Flask API
echo "7. Updating API configuration..."
sed -i "s/host=\"localhost\"/host=\"localhost\"/g" $BOOKING_DIR/booking_api.py
sed -i "s/user=\"root\"/user=\"$DB_USER\"/g" $BOOKING_DIR/booking_api.py
sed -i "s/password=\"Lol212223\"/password=\"$DB_PASS\"/g" $BOOKING_DIR/booking_api.py
sed -i "s/database=\"computer_booking\"/database=\"$DB_NAME\"/g" $BOOKING_DIR/booking_api.py

# 8. Create systemd service for the Flask API
echo "8. Creating Systemd service for the API..."
cat > /etc/systemd/system/booking-api.service << EOF
[Unit]
Description=Booking API Flask Service
After=network.target

[Service]
User=www-data
WorkingDirectory=$BOOKING_DIR
ExecStart=/usr/bin/python3 $BOOKING_DIR/booking_api.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# 9. Apache configuration
echo "9. Configuring Apache..."
cat > /etc/apache2/sites-available/booking.conf << EOF
<VirtualHost *:80>
    ServerName booking.local
    DocumentRoot $BOOKING_DIR
    
    <Directory $BOOKING_DIR>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
    
    ErrorLog \${APACHE_LOG_DIR}/booking-error.log
    CustomLog \${APACHE_LOG_DIR}/booking-access.log combined
</VirtualHost>
EOF

# Enable Apache modules
a2enmod rewrite
a2ensite booking.conf

# 10. Set permissions
echo "10. Setting permissions..."
chown -R www-data:www-data $BOOKING_DIR
chmod -R 755 $BOOKING_DIR

# 11. Start services
echo "11. Starting services..."
systemctl daemon-reload
systemctl enable booking-api.service
systemctl start booking-api.service
systemctl restart apache2

# 12. Fix the API endpoint in index.php
echo "12. Updating API endpoint in the website..."
SERVER_IP=$(hostname -I | awk '{print $1}')
sed -i "s|http://172.18.16.93:5000|http://$SERVER_IP:5000|g" $BOOKING_DIR/index.php

echo "=== Deployment completed ==="
echo "The Booking component has been successfully set up."
echo "Database: $DB_NAME"
echo "Database user: $DB_USER"
echo "Database password: $DB_PASS"
echo "API URL: http://$SERVER_IP:5000"
echo "Website: http://$SERVER_IP/booking"
echo ""
echo "Please note this information for future reference." 