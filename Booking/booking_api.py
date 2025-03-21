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
        user="admin",
        password="admin",
        database="computer_booking"
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
