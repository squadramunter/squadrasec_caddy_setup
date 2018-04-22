##Easy Caddy Server Installer Made by @SquadraSec #Bash

apt install curl php7.0 php7.0-curl php7.0-gd php7.0-imap php7.0-json php7.0-mcrypt php7.0-mysql php7.0-opcache php7.0-xmlrpc libapache2-mod-php7.0 php7.0-fpm php7.0-zip php7.0-xml php7.0-mbstring unzip
sed -i '/listen =/c\listen = 127.0.0.1:9000' /etc/php/7.0/fpm/pool.d/www.conf
curl https://getcaddy.com | bash -s personal dyndns,hook.service,http.authz,http.awses,http.awslambda,http.cache,http.cgi,http.cors,http.datadog,http.expires,http.filemanager,http.filter,http.forwardproxy,http.geoip,http.git,http.gopkg,http.grpc,http.hugo,http.ipfilter,http.jekyll,http.jwt,http.locale,http.login,http.mailout,http.minify,http.nobots,http.prometheus,http.proxyprotocol,http.ratelimit,http.realip,http.reauth,http.restic,http.upload,http.webdav,net,tls.dns.cloudflare

chown root:root /usr/local/bin/caddy
chmod 755 /usr/local/bin/caddy
setcap 'cap_net_bind_service=+eip' /usr/local/bin/caddy
mkdir -p /etc/caddy
chown -R root:www-data /etc/caddy
mkdir -p /etc/ssl/caddy
chown -R www-data:root /etc/ssl/caddy
chmod 770 /etc/ssl/caddy
touch /etc/caddy/Caddyfile

echo "What is your domain name FQDN?"
read domain

echo "If you want TLS secure connection to be enabled give your email address here!"
read email

mkdir -p /var/www/{dl,cloud}.$domain/html
chown www-data:www-data /var/www
chmod 775 /var/www

##NextCloud setup...

wget https://download.nextcloud.com/server/releases/nextcloud-13.0.1.zip -P /tmp/
unzip /tmp/nextcloud-13.0.1.zip -d /tmp/
cp -a /tmp/nextcloud/. /var/www/cloud.$domain/html/
chown -R www-data:www-data /var/www/cloud.$domain/html
chmod -R a+x /var/www/cloud.$domain/html

##Nextcloud PHP performance settings...
sed -i '/;opcache.enable=0/c\opcache.enable=1' /etc/php/7.0/fpm/php.ini
sed -i '/;opcache.enable_cli=0/c\opcache.enable_cli=1' /etc/php/7.0/fpm/php.ini
sed -i '/;opcache.interned_strings_buffer=/c\opcache.interned_strings_buffer=8' /etc/php/7.0/fpm/php.ini
sed -i '/;opcache.max_accelerated_files=/c\opcache.max_accelerated_files=10000' /etc/php/7.0/fpm/php.ini
sed -i '/;opcache.memory_consumption=/c\opcache.memory_consumption=128' /etc/php/7.0/fpm/php.ini
sed -i '/;opcache.save_comments=/c\opcache.save_comments=1' /etc/php/7.0/fpm/php.ini
sed -i '/;opcache.revalidate_freq=/c\opcache.revalidate_freq=1' /etc/php/7.0/fpm/php.ini

##Caddy web server setup...

sudo wget https://raw.githubusercontent.com/mholt/caddy/master/dist/init/linux-systemd/caddy.service
sudo cp caddy.service /etc/systemd/system/
sudo chown root:root /etc/systemd/system/caddy.service
sudo chmod 644 /etc/systemd/system/caddy.service
sudo systemctl daemon-reload
sudo touch /etc/caddy/Caddyfile

CFILE="/etc/caddy/Caddyfile"

/bin/cat <<EOM >$CFILE

$domain {
    redir https://www.$domain{uri}
}

https://www.$domain {

redir 301 {
	if {>X-Forwarded-Proto} is http
	/  https://{host}{uri}
}

    tls $email
    proxy / 127.0.0.1:2368 {
        websocket
    }
}

cloud.$domain {
    redir https://www.cloud.$domain{uri}
}

https://www.cloud.$domain {

redir 301 {
	if {>X-Forwarded-Proto} is http
	/  https://{host}{uri}
}
	
	gzip
	tls    $email
	root   /var/www/cloud.$domain/html
	log    /var/log/nextcloud_access.log
	errors /var/log/nextcloud_errors.log

	fastcgi / 127.0.0.1:9000 php {
		env PATH /bin
	}
	
	# checks for images
        rewrite {
	        ext .svg .gif .png .html .ttf .woff .ico .jpg .jpeg
		r ^/index.php/(.+)$
		to /{1} /index.php?{1}
	}

	rewrite {
		r ^/index.php/.*$
		to /index.php?{query}
	}

	# client support (e.g. os x calendar / contacts)
	redir /.well-known/carddav /remote.php/carddav 301
	redir /.well-known/caldav /remote.php/caldav 301

	# remove trailing / as it causes errors with php-fpm
	rewrite {
		r ^/remote.php/(webdav|caldav|carddav|dav)(\/?)$
		to /remote.php/{1}
	}

	rewrite {
		r ^/remote.php/(webdav|caldav|carddav|dav)/(.+?)(\/?)$
		to /remote.php/{1}/{2}
	}

	rewrite {
		r ^/public.php/(dav|webdav|caldav|carddav)(\/?)$
		to /public.php/{1}
	}

	rewrite {
		r ^/public.php/(dav|webdav|caldav|carddav)/(.+)(\/?)$
		to /public.php/{1}/{2}
	}

	# .htaccess / data / config / ... shouldn't be accessible from outside
	status 403 {
		/.htacces
		/data
		/config
		/db_structure
		/.xml
		/README
	}

	header / Strict-Transport-Security "max-age=31536000;"

}

EOM
