#!/bin/bash

# به‌روزرسانی سیستم
sudo apt-get update -y && sudo apt-get upgrade -y

# نصب Nginx و PHP
sudo apt-get install nginx php8.1-fpm php8.1-mysql unzip curl -y

# راه‌اندازی PHP-FPM
sudo systemctl start php8.1-fpm
sudo systemctl enable php8.1-fpm

# تنظیمات فایروال برای Nginx
sudo ufw allow 'Nginx HTTP'
sudo ufw allow 8080

# دانلود و نصب پنل مدیریت DNS
wget -O /tmp/dns-panel.zip https://github.com/shayan9023/dns/archive/refs/heads/main.zip
unzip /tmp/dns-panel.zip -d /var/www/html/
sudo mv /var/www/html/dns-main /var/www/html/dns-panel
sudo chown -R www-data:www-data /var/www/html/dns-panel

# تنظیمات Nginx
sudo tee /etc/nginx/sites-available/dns-panel <<EOF
server {
    listen 8080;
    server_name localhost;
    root /var/www/html/dns-panel;
    index index.php;
    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.1-fpm.sock;
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

# نمایش آدرس پنل
IP=$(curl -s ifconfig.me)
echo "پنل با موفقیت نصب شد! می‌توانید از طریق: http://$IP:8080 به آن دسترسی پیدا کنید."
