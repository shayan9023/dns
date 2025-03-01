#!/bin/bash
# DNS Management Panel with Unbound
# Author: ChatGPT

# Install necessary packages
apt-get update && apt-get install -y unbound nginx php-fpm sqlite3 php-sqlite3

# Unbound configuration
cat << EOF > /etc/unbound/unbound.conf
server:
    verbosity: 1
    interface: 0.0.0.0
    access-control: 0.0.0.0/0 allow
    username: unbound
    directory: "/etc/unbound"
    logfile: "/var/log/unbound/unbound.log"

remote-control:
    control-enable: yes
EOF

# Restart Unbound
systemctl restart unbound

# Create SQLite database for users
sqlite3 /var/www/html/users.db "CREATE TABLE IF NOT EXISTS users (id INTEGER PRIMARY KEY, username TEXT, quota INTEGER, time INTEGER, created_at DATETIME DEFAULT CURRENT_TIMESTAMP);"

# Nginx configuration for PHP
cat << EOF > /etc/nginx/sites-available/default
server {
    listen 80;
    root /var/www/html;
    index index.php index.html;

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php-fpm.sock;
    }
}
EOF

# Restart Nginx
systemctl restart nginx

# PHP script for user management
cat << 'PHP' > /var/www/html/index.php
<?php
$db = new SQLite3('users.db');
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $username = $_POST['username'];
    $quota = $_POST['quota'];
    $time = $_POST['time'];
    $db->exec("INSERT INTO users (username, quota, time) VALUES ('$username', $quota, $time);");
}
?>
<form method="post">
    <input type="text" name="username" placeholder="Username" required />
    <input type="number" name="quota" placeholder="Quota (0 for unlimited)" />
    <input type="number" name="time" placeholder="Time (0 for unlimited)" />
    <button type="submit">Create User</button>
</form>
PHP

# Set permissions
chown -R www-data:www-data /var/www/html

# All done!
echo "DNS Management Panel setup complete!"
