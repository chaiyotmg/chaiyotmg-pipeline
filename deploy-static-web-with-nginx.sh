#!/bin/bash
echo "Start script deploy static web with nginx! without SSL"
echo "========================================================"
# ชื่อ app 
APP_NAME="react-app"
# folder ชื่อ dist หรือ folder ที่ build แล้ว
APP_BUILD_PATH="/home/chaiyot_mg/react-app"
SITE_ENABLED_PATH="/etc/nginx/sites-enabled"
SITE_AVAILABLE_PATH="/etc/nginx/sites-available"
echo "App name : $APP_NAME"
echo "========================================================"
cat <<EOF > $SITE_AVAILABLE_PATH/$APP_NAME
    server { 
        listen 80; 
        listen [::]:80;  
        root /var/www/$APP_NAME; 
        index index.html; 

        location / {
            try_files \$uri /index.html;
        }
    }
EOF
echo "$SITE_AVAILABLE_PATH/$APP_NAME"
echo "========================================================"
cat $SITE_AVAILABLE_PATH/$APP_NAME
echo "========================================================"
if [ -L "$SITE_ENABLED_PATH/default" ]; then
    sudo unlink $SITE_ENABLED_PATH/default
fi

if [ -L "$SITE_ENABLED_PATH/$APP_NAME" ]; then
    sudo unlink $SITE_ENABLED_PATH/$APP_NAME
fi

if [ ! -d /var/www/$APP_NAME ]; then
    sudo mkdir -p /var/www/$APP_NAME
    sudo chmod -R 755 /var/www/$APP_NAME
    # www-data คือ Nginx user group.
    sudo chown -R www-data:www-data /var/www/$APP_NAME
else
    rm -rf /var/www/$APP_NAME/*
fi

# copy ไฟล์จาก folder ชั่งคราวไปยัง folder app
sudo cp -r $APP_BUILD_PATH/* /var/www/$APP_NAME/
sudo ln -s $SITE_AVAILABLE_PATH/$APP_NAME $SITE_ENABLED_PATH/
sudo systemctl restart nginx
sudo nginx -t
echo "========================================================"
sudo systemctl status nginx | head -n 40
echo "========================================================"
echo "End script!"


