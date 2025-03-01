#!/bin/bash

# رنگ‌ها برای خروجی
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${GREEN}🔥 شروع نصب پنل مدیریت DNS...${NC}"

# آپدیت پکیج‌ها و نصب وابستگی‌ها
sudo apt-get update
sudo apt-get install -y nginx php-fpm php-mysql mariadb-server curl

# استارت سرویس‌های Nginx و MariaDB
sudo systemctl enable nginx mariadb
sudo systemctl start nginx mariadb

# ساخت دیتابیس و کاربر
echo -e "${GREEN}📦 ساخت دیتابیس و جداول...${NC}"
sudo mysql -e "CREATE DATABASE IF NOT EXISTS dns_panel;"
sudo mysql -e "CREATE USER IF NOT EXISTS 'dns_user'@'localhost' IDENTIFIED BY 'dns_pass';"
sudo mysql -e "GRANT ALL PRIVILEGES ON dns_panel.* TO 'dns_user'@'localhost';"
sudo mysql -e "FLUSH PRIVILEGES;"
sudo mysql -e "USE dns_panel; CREATE TABLE IF NOT EXISTS users (id INT AUTO_INCREMENT PRIMARY KEY, username VARCHAR(50), quota INT, time INT);"

# ساخت مسیر و دانلود کدهای پنل
sudo mkdir -p /var/www/html/dns-panel
sudo tee /var/www/html/dns-panel/index.php > /dev/null << 'EOF'
<!DOCTYPE html>
<html lang="fa">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>مدیریت DNS</title>
<link href="https://cdn.jsdelivr.net/npm/tailwindcss@2.2.19/dist/tailwind.min.css" rel="stylesheet">
</head>
<body class="bg-gray-100 text-gray-800">
<div class="container mx-auto p-6">

    <h1 class="text-2xl font-bold mb-4">پنل مدیریت DNS</h1>

    <form action="" method="POST" class="mb-6 bg-white p-4 rounded shadow-md">
        <h2 class="text-xl font-semibold mb-2">ایجاد یوزر جدید</h2>
        <div class="mb-4">
            <label>نام کاربری:</label>
            <input type="text" name="username" class="border p-2 w-full" required>
        </div>
        <div class="mb-4">
            <label>حجم (مگابایت):</label>
            <input type="number" name="quota" class="border p-2 w-full" required>
        </div>
        <div class="mb-4">
            <label>زمان (دقیقه):</label>
            <input type="number" name="time" class="border p-2 w-full" required>
        </div>
        <button type="submit" name="add_user" class="bg-blue-500 text-white p-2 rounded">ایجاد یوزر</button>
    </form>

    <?php
    $conn = new mysqli("localhost", "dns_user", "dns_pass", "dns_panel");

    if ($conn->connect_error) {
        die("خطا در اتصال به دیتابیس: " . $conn->connect_error);
    }

    if (isset($_POST['add_user'])) {
        $username = $_POST['username'];
        $quota = $_POST['quota'];
        $time = $_POST['time'];
        $conn->query("INSERT INTO users (username, quota, time) VALUES ('$username', $quota, $time)");
    }

    if (isset($_GET['delete_user'])) {
        $id = $_GET['delete_user'];
        $conn->query("DELETE FROM users WHERE id = $id");
    }

    $result = $conn->query("SELECT * FROM users");
    ?>

    <h2 class="text-xl font-semibold mb-2">لیست یوزرها</h2>
    <table class="min-w-full bg-white rounded shadow-md">
        <thead>
            <tr>
                <th class="py-2">نام کاربری</th>
                <th class="py-2">حجم</th>
                <th class="py-2">زمان</th>
                <th class="py-2">وضعیت</th>
                <th class="py-2">عملیات</th>
            </tr>
        </thead>
        <tbody>
            <?php while ($row = $result->fetch_assoc()): ?>
                <tr class="text-center border-b">
                    <td class="py-2"><?php echo $row['username']; ?></td>
                    <td class="py-2"><?php echo $row['quota'] == 0 ? 'نامحدود' : $row['quota'] . ' MB'; ?></td>
                    <td class="py-2"><?php echo $row['time'] == 0 ? 'نامحدود' : $row['time'] . ' دقیقه'; ?></td>
                    <td class="py-2">
                        <?php echo ($row['quota'] == 0 && $row['time'] == 0) ? '<span class="text-green-500">نامحدود</span>' : '<span class="text-blue-500">فعال</span>'; ?>
                    </td>
                    <td class="py-2">
                        <a href="?delete_user=<?php echo $row['id']; ?>" class="bg-red-500 text-white p-1 rounded">حذف</a>
                    </td>
                </tr>
            <?php endwhile; ?>
        </tbody>
    </table>

</div>
</body>
</html>
EOF

# تنظیمات Nginx برای پنل
sudo tee /etc/nginx/sites-available/dns-panel > /dev/null << 'EOF'
server {
    listen 80;
    server_name _;

    root /var/www/html/dns-panel;
    index index.php index.html;

    location / {
        try_files $uri $uri/ =404;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }
}
EOF

sudo ln -sf /etc/nginx/sites-available/dns-panel /etc/nginx/sites-enabled/
sudo systemctl restart nginx

echo -e "${GREEN}✅ نصب پنل کامل شد! آدرس: http://your-server-ip${NC}"
