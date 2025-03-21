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

# Bestimme die richtige Webserver-Gruppe basierend auf der Distribution
if command -v apt-get &> /dev/null; then
    # Debian/Ubuntu
    WEB_GROUP="www-data"
elif command -v dnf &> /dev/null; then
    # Fedora
    WEB_GROUP="apache"
else
    # Fallback
    WEB_GROUP="www-data"
fi

# Prüfe, ob die Webserver-Gruppe existiert, sonst erstelle sie
if ! getent group $WEB_GROUP > /dev/null; then
    echo "Group $WEB_GROUP does not exist. Creating group..."
    groupadd $WEB_GROUP
fi

# Prompt for system user
read -p "Enter system username for the booking service: " SYSTEM_USER
# Check if user exists
if id "$SYSTEM_USER" &>/dev/null; then
    echo "Using existing user: $SYSTEM_USER"
else
    echo "User $SYSTEM_USER does not exist. Creating user..."
    read -s -p "Enter password for new user $SYSTEM_USER: " USER_PASSWORD
    echo ""
    useradd -m -s /bin/bash "$SYSTEM_USER"
    echo "$SYSTEM_USER:$USER_PASSWORD" | chpasswd
    # Add user to necessary groups
    usermod -aG $WEB_GROUP "$SYSTEM_USER"
fi

# Prompt for database password
read -s -p "Enter database password for the booking service: " DB_PASSWORD
echo ""

# Define variables
BOOKING_DIR="."
DB_NAME="computer_booking"
DB_USER="$SYSTEM_USER"  # Use the system user as database user

# 1. Install dependencies
echo "1. Installing dependencies..."
if command -v apt-get &> /dev/null; then
    # Debian/Ubuntu
    apt-get update
    apt-get install -y apache2 php php-mysql mysql-server python3 python3-pip
elif command -v dnf &> /dev/null; then
    # Fedora
    dnf update -y
    dnf install -y httpd php php-mysqlnd mysql-server python3 python3-pip
else
    echo "Error: Package manager not supported"
    exit 1
fi

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
mysql -e "CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASSWORD';"
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
# First, create a backup of the original file
cp $BOOKING_DIR/booking_api.py $BOOKING_DIR/booking_api.py.bak

# Update the database connection details in the API file
cat > $BOOKING_DIR/booking_api.py << EOF
from flask import Flask, request, jsonify
from flask_cors import CORS
import mysql.connector
import logging
import re
from datetime import datetime

app = Flask(__name__)
CORS(app)  # Enable CORS for all endpoints

# Set up logging so that errors are printed to the console.
logging.basicConfig(level=logging.DEBUG)

# Function to get a new database connection.
def get_db_connection():
    return mysql.connector.connect(
        host="localhost",
        user="$DB_USER",
        password="$DB_PASSWORD",
        database="$DB_NAME"
    )

# Helper function: Validate user inputs
def is_valid_input(computer, user, email, start_time, end_time):
    """
    Perform validation checks on input data:
    - computer: No special characters, only letters, numbers, dashes, and underscores
    - user: No special characters, only letters, spaces, and dashes
    - email: Must be a valid email format
    - start_time, end_time: Must be valid datetime format
    """
    
    computer_pattern = re.compile(r"^[a-zA-Z0-9-_]+$")
    user_pattern = re.compile(r"^[a-zA-Z0-9\s-]+$")
    email_pattern = re.compile(r"^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+$")

    if not (computer and user and email and start_time and end_time):
        return False, "All fields are required."

    if not computer_pattern.match(computer):
        return False, "Invalid computer name format."

    if not user_pattern.match(user):
        return False, "Invalid user name format."

    if not email_pattern.match(email):
        return False, "Invalid email format."

    # Ensure start_time and end_time are valid datetime values
    try:
        datetime.fromisoformat(start_time)
        datetime.fromisoformat(end_time)
    except ValueError:
        return False, "Invalid date format. Use ISO format (YYYY-MM-DDTHH:MM:SS)."

    return True, None

@app.route('/computers', methods=['GET'])
def get_computers():
    try:
        cnx = get_db_connection()
        cursor = cnx.cursor(dictionary=True)
        query = "SELECT id, name, status FROM computers"
        cursor.execute(query)
        computers = cursor.fetchall()
        cursor.close()
        cnx.close()
        return jsonify(computers)
    except Exception as e:
        app.logger.error("Error in /computers endpoint: %s", e)
        return jsonify({"error": "Internal server error"}), 500

@app.route('/status', methods=['GET'])
def get_status():
    try:
        cnx = get_db_connection()
        cursor = cnx.cursor(dictionary=True)
        # Note: The query selects the columns you need from the bookings table.
        query = "SELECT computer_name, user, email, start_time, end_time, status FROM bookings"
        cursor.execute(query)
        bookings = cursor.fetchall()
        cursor.close()
        cnx.close()
        return jsonify(bookings)
    except Exception as e:
        app.logger.error("Error in /status endpoint: %s", e)
        return jsonify({"error": "Internal server error"}), 500

@app.route('/available', methods=['GET'])
def check_availability():
    try:
        cnx = get_db_connection()
        cursor = cnx.cursor(dictionary=True)

        # Get current UTC time
        current_time = datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S')

        # Query all computers
        cursor.execute("SELECT id, name FROM computers")
        computers = cursor.fetchall()

        # Query for currently booked computers
        booked_query = """
            SELECT computer_name, user, end_time 
            FROM bookings 
            WHERE status = 'booked' 
              AND %s BETWEEN start_time AND end_time
        """
        cursor.execute(booked_query, (current_time,))
        booked_computers = {}
        for row in cursor.fetchall():
            row["end_time"] = row["end_time"].strftime('%d.%m.%Y')  # Format date
            booked_computers[row["computer_name"]] = row

        # Query for next upcoming bookings for ALL computers
        upcoming_query = """
            SELECT computer_name, user, start_time 
            FROM bookings 
            WHERE status = 'booked' 
              AND start_time > %s
            ORDER BY start_time ASC
        """
        cursor.execute(upcoming_query, (current_time,))
        upcoming_bookings = {}
        for row in cursor.fetchall():
            row["start_time"] = row["start_time"].strftime('%d.%m.%Y')  # Format date
            upcoming_bookings[row["computer_name"]] = row  # Only store first upcoming

        cursor.close()
        cnx.close()

        # Prepare response
        availability_list = []
        for computer in computers:
            name = computer["name"]
            status = "🟢"
            availability = "---"
            booked_by = "---"  # Default to "---" if no bookings

            if name in booked_computers:
                # Currently booked
                status = "🔴"
                availability = f"bis {booked_computers[name]['end_time']}"
                booked_by = booked_computers[name]["user"]
            elif name in upcoming_bookings:
                # Not booked but has an upcoming booking
                availability = f"ab {upcoming_bookings[name]['start_time']}"
                booked_by = upcoming_bookings[name]["user"]
            else:
                # No upcoming bookings
                availability = "---"
                booked_by = "---"

            availability_list.append({
                "id": computer["id"],
                "computer_name": name,
                "available": status,
                "availability": availability,
                "booked_by": booked_by
            })

        return jsonify(availability_list)

    except Exception as e:
        app.logger.error("Error in /available endpoint: %s", e)
        return jsonify({"error": "Internal server error"}), 500

@app.route('/book', methods=['POST'])
def book_computer():
    try:
        data = request.json
        if not data:
            return jsonify({"error": "Invalid JSON input"}), 400

        # The booking form is expected to send these fields.
        computer = data.get("computer_name")  # Note: our PHP proxy sends "computer_name"
        user = data.get("user")
        email = data.get("email")
        start_time = data.get("start_time")
        end_time = data.get("end_time")

        # Validate user input before processing
        is_valid, error_message = is_valid_input(computer, user, email, start_time, end_time)
        if not is_valid:
            return jsonify({"error": error_message}), 400

        cnx = get_db_connection()
        cursor = cnx.cursor(dictionary=True)

        # Check for overlapping bookings.
        overlap_query = """
            SELECT COUNT(*) AS cnt FROM bookings
            WHERE computer_name = %s
              AND status = 'booked'
              AND (%s < end_time AND %s > start_time)
        """
        params = (computer, end_time, start_time)
        cursor.execute(overlap_query, params)
        overlap_result = cursor.fetchone()
        if overlap_result and overlap_result["cnt"] > 0:
            cursor.close()
            cnx.close()
            return jsonify({"error": "This computer is already booked for the selected time range."}), 409

        # Insert the booking.
        insert_query = """
            INSERT INTO bookings (computer_name, user, email, start_time, end_time, status)
            VALUES (%s, %s, %s, %s, %s, 'booked')
        """
        cursor.execute(insert_query, (computer, user, email, start_time, end_time))
        cnx.commit()
        cursor.close()
        cnx.close()

        return jsonify({"message": f"Computer {computer} booked by {user}"}), 201
    except Exception as e:
        app.logger.error("Error in /book endpoint: %s", e)
        return jsonify({"error": "Internal server error"}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
EOF

# 8. Create systemd service for the Flask API
echo "8. Creating Systemd service for the API..."
cat > /etc/systemd/system/booking-api.service << EOF
[Unit]
Description=Booking API Flask Service
After=network.target

[Service]
User=$SYSTEM_USER
Group=$WEB_GROUP
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
chown -R $SYSTEM_USER:$WEB_GROUP $BOOKING_DIR
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
echo "System user: $SYSTEM_USER"
echo "Database: $DB_NAME"
echo "Database user: $DB_USER"
echo "Database password: $DB_PASSWORD"
echo "API URL: http://$SERVER_IP:5000"
echo "Website: http://$SERVER_IP/booking"
echo ""
echo "Please note this information for future reference." 