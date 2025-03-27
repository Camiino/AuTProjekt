<?php
header("Content-Type: application/json"); // Ensure correct response type

if ($_SERVER["REQUEST_METHOD"] == "POST") {
    // Read JSON input
    $data = json_decode(file_get_contents("php://input"), true);

    if (!$data) {
        echo json_encode(["error" => "Invalid JSON input"]);
        exit;
    }

    $computer = $data["computer"] ?? null;
    $user = $data["user"] ?? null;
    $email = $data["email"] ?? null;
    $start_time = $data["start_time"] ?? null;
    $end_time = $data["end_time"] ?? null;

    if (!$computer || !$user || !$email || !$start_time || !$end_time) {
        echo json_encode(["error" => "Missing required parameters"]);
        exit;
    }

    $api_url = "http://localhost:5000/book"; // Flask API URL
    $payload = json_encode([
        "computer_name" => $computer,
        "user" => $user,
        "email" => $email,
        "start_time" => $start_time,
        "end_time" => $end_time
    ]);

    $options = [
        "http" => [
            "header"  => "Content-Type: application/json\r\n",
            "method"  => "POST",
            "content" => $payload,
        ],
    ];

    $context  = stream_context_create($options);
    $result = @file_get_contents($api_url, false, $context);
    
    if ($result === FALSE) {
        echo json_encode(["error" => "Booking failed, Flask API unreachable"]);
        exit;
    }

    $response = json_decode($result, true);
    echo json_encode($response);
} else {
    echo json_encode(["error" => "Invalid request method"]);
}
?>
