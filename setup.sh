#!/bin/bash

# به‌روزرسانی سیستم
sudo apt-get update -y && sudo apt-get upgrade -y

# نصب Nginx، PHP و MariaDB
sudo apt-get install nginx php8.1-fpm php8.1-mysql mariadb-server unzip curl -y

# راه‌اندازی و فعال‌سازی PHP-FPM و MariaDB
sudo systemctl start php8.1-fpm mariadb
sudo systemctl enable php8.1-fpm mariadb

# تنظیم رمز عبور برای کاربر root در MariaDB
sudo mysql -e "UPDATE mysql.user SET Password = PASSWORD('your_password_here') WHERE User = 'root';"
sudo mysql -e "FLUSH PRIVILEGES;"

# ایجاد پایگاه داده و کاربر برای پنل مدیریت DNS
DB_NAME="dns_panel"
DB_USER="dns_user"
DB_PASS="your_db_password_here"

sudo mysql -e "CREATE DATABASE $DB_NAME;"
sudo mysql -e "CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';"
sudo mysql -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';"
sudo mysql -e "FLUSH PRIVILEGES;"

# دانلود و نصب پنل مدیریت DNS
wget -O /tmp/dns-panel.zip https://github.com/shayan9023/dns/archive/refs/heads/main.zip
unzip /tmp/dns-panel.zip -d /var/www/html/
sudo mv /var/www/html/dns-main/* /var/www/html/
sudo rm -r /var/www/html/dns-main
sudo chown -R www-data:www-data /var/www/html/

# ساخت صفحه 404 سفارشی
echo '<h1>404 - صفحه مورد نظر یافت نشد!</h1>' | sudo tee /var/www/html/404.html

# تنظیمات Nginx
sudo tee /etc/nginx/sites-available/dns-panel <<EOF
server {
    listen 80;
    server_name localhost;
    root /var/www/html;
    index index.php;
    error_page 404 /404.html;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.1-fpm.sock;
    }
    location = /404.html {
        internal;
    }
}
EOF

# فعال‌سازی سایت و ریستارت Nginx
sudo ln -s /etc/nginx/sites-available/dns-panel /etc/nginx/sites-enabled/
sudo systemctl restart nginx

# بررسی خطاهای Nginx
sudo nginx -t
if [ $? -ne 0 ]; then
    echo "خطایی در تنظیمات Nginx وجود دارد!"
    exit 1
fi

# بررسی وضعیت سرویس‌ها
sudo systemctl status nginx | head -n 10
sudo systemctl status php8.1-fpm | head -n 10
sudo systemctl status mariadb | head -n 10

# نمایش آدرس پنل
IP=$(curl -s ifconfig.me)
echo "پنل با موفقیت نصب شد! می‌توانید از طریق: http://$IP به آن دسترسی پیدا کنید."
