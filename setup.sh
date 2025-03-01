#!/bin/bash

# نصب وابستگی‌ها
apt-get update
apt-get install -y nginx php-fpm sqlite3 php-sqlite3 curl

# ساخت دیتابیس
DB_PATH="/var/www/html/dns-panel/users.db"
mkdir -p /var/www/html/dns-panel
sqlite3 $DB_PATH "CREATE TABLE IF NOT EXISTS users (id INTEGER PRIMARY KEY AUTOINCREMENT, username TEXT, quota INTEGER, time INTEGER, dns_link TEXT, password TEXT);"

# ساخت صفحه لاگین
cat <<EOF > /var/www/html/dns-panel/index.php
<?php
session_start();
\$db = new PDO('sqlite:$DB_PATH');

if (isset(\$_POST['login'])) {
    \$stmt = \$db->prepare("SELECT * FROM users WHERE username = ? AND password = ?");
    \$stmt->execute([\$_POST['username'], \$_POST['password']]);
    \$user = \$stmt->fetch();
    if (\$user) {
        \$_SESSION['user'] = \$user;
        header('Location: /dns-panel/dashboard.php');
        exit();
    } else {
        echo "<p style='color: red;'>نام کاربری یا رمز عبور اشتباه است!</p>";
    }
}
?>
<html>
<head><title>ورود ادمین</title></head>
<body style="background-color: #121212; color: #fff; text-align: center;">
    <h2 style="color: #3498db;">ورود به پنل DNS</h2>
    <form method="post">
        <input type="text" name="username" placeholder="نام کاربری" required><br>
        <input type="password" name="password" placeholder="رمز عبور" required><br>
        <button type="submit" name="login">ورود</button>
    </form>
</body>
</html>
EOF

# ساخت صفحه داشبورد
cat <<EOF > /var/www/html/dns-panel/dashboard.php
<?php
session_start();
if (!isset(\$_SESSION['user'])) {
    header('Location: /dns-panel/index.php');
    exit();
}
\$db = new PDO('sqlite:$DB_PATH');
\$users = \$db->query("SELECT * FROM users")->fetchAll();
?>
<html>
<head><title>پنل DNS</title></head>
<body style="background-color: #121212; color: #fff;">
<h2 style="color: #3498db; text-align: center;">لیست کاربران</h2>
<table border="1" style="width: 80%; margin: auto; color: #fff;">
<tr><th>نام کاربری</th><th>حجم</th><th>زمان</th><th>لینک DNS</th><th>حذف</th></tr>
<?php foreach (\$users as \$user): ?>
<tr>
    <td><?php echo \$user['username']; ?></td>
    <td><?php echo \$user['quota'] ? \$user['quota'] . ' GB' : 'نامحدود'; ?></td>
    <td><?php echo \$user['time'] ? \$user['time'] . ' روز' : 'نامحدود'; ?></td>
    <td><input type="text" value="<?php echo \$user['dns_link']; ?>" readonly></td>
    <td><a href="delete.php?id=<?php echo \$user['id']; ?>">حذف</a></td>
</tr>
<?php endforeach; ?>
</table>
</body>
</html>
EOF

# تنظیمات Nginx
cat <<EOF > /etc/nginx/sites-available/dns-panel
server {
    listen 8080;
    root /var/www/html/dns-panel;
    index index.php;
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php-fpm.sock;
    }
}
EOF

ln -s /etc/nginx/sites-available/dns-panel /etc/nginx/sites-enabled/
systemctl restart nginx

echo "نصب و راه‌اندازی پنل DNS با موفقیت انجام شد!"
