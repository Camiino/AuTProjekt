#!/bin/bash

# Check if script is running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root (sudo)"
    exit 1
fi
sudo apt-get install mysql-server php-cli php php-mysql python3 python3-pip
python3 -m venv booking
source booking/bin/activate

python --version
pip --version

pip install Flask
pip install flask-cors
pip install mysql-connector-python
pip install regex

cp booking_api.py booking/
cp book.php booking/
cp index.php booking/
cp index.css booking/

cd booking

echo "enabling mysql"
sudo systemctl enable mysql
sudo systemctl status mysql


echo "Setting up Database"
sudo mysql -e "CREATE DATABASE IF NOT EXISTS computer_booking;"
sudo mysql -e "CREATE USER IF NOT EXISTS 'aut'@'localhost' IDENTIFIED BY 'aut';"
sudo mysql -e "GRANT ALL PRIVILEGES ON computer_booking.* TO 'aut'@'localhost';"
sudo mysql -e "FLUSH PRIVILEGES;"

echo "Creating db-tables"
sudo mysql computer_booking << EOF
CREATE TABLE IF NOT EXISTS computers (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE,
    status ENUM('available', 'booked') DEFAULT 'available'
);

CREATE TABLE IF NOT EXISTS bookings (
    id INT AUTO_INCREMENT PRIMARY KEY,
    computer_name VARCHAR(50) NOT NULL,
    user VARCHAR(50) NOT NULL,
    email VARCHAR(255) NOT NULL,
    start_time DATETIME NOT NULL,
    end_time DATETIME NOT NULL,
    status ENUM('available', 'booked') DEFAULT 'booked',
    INDEX (computer_name),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (computer_name) REFERENCES computers(name) ON DELETE CASCADE ON UPDATE CASCADE
);

-- Insert example computers
INSERT INTO computers (name, status) VALUES 
('eiba-dl2', 'available'),
('kiphotoline', 'available'),
('tornado', 'available');
EOF

php -S localhost:8000