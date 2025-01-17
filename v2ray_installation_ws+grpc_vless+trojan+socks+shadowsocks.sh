#!/bin/bash
# Auth: syra
# Desc: v2ray installation script
# 	ws+vless,ws+trojan,ws+socks,ws+shadowsocks
#	grpc+vless,grpc+trojan,grpc+socks,grpc+shadowsocks
# Plat: ubuntu 18.04+
# Eg  : bash v2ray_installation_ws+grpc_vless+trojan+socks+shadowsocks.sh "nama domain Anda"

if [ -z "id.syra.co.id" ];then
	echo "Nama domain tidak boleh kosong"
	exit
fi

# Konfigurasikan zona waktu sistem sebagai Distrik Kedelapan Timur, dan atur waktu ke 24H
ln -sf /usr/share/zoneinfo/Asia/Jakarta /etc/localtime
if ! grep -q 'LC_TIME' /etc/default/locale;then echo 'LC_TIME=en_DK.UTF-8' >> /etc/default/locale;fi


# Perbarui sumber resmi Ubuntu, gunakan sumber resmi ubuntu untuk menginstal nginx dan paket dependen dan mengatur startup, tutup firewall ufw
apt clean all && apt update && apt upgrade -y
apt install socat nginx curl pwgen openssl netcat cron -y
systemctl enable nginx
ufw disable


# Sebelum memulai penerapan, mari kita konfigurasikan parameter yang perlu digunakan, sebagai berikut: 27 
# "nama domain, uuid, jalur ws dan grpc, direktori domainSock, direktori sertifikat ssl"

# 1. Tetapkan nama domain Anda yang telah diselesaikan
domainName="id.syra.co.id"

# 2. Secara acak menghasilkan uuid
uuid="`uuidgen`"

# 3. Buat port layanan secara acak yang perlu digunakan oleh socks dan shadowsocks
socks_ws_port="`shuf -i 20000-30000 -n 1`"
shadowsocks_ws_port="`shuf -i 30001-40000 -n 1`"
socks_grpc_port="`shuf -i 40001-50000 -n 1`"
shadowsocks_grpc_port="`shuf -i 50001-60000 -n 1`"

# 4. Buat kata sandi pengguna trojan, socks, dan shadowsocks secara acak
trojan_passwd="syra"
socks_user="syra"
socks_passwd="syra"
shadowsocks_passwd="syra"

# 5. Gunakan WS untuk mengonfigurasi protokol vless, trojan, socks, shadowsocks 48 
# Secara acak menghasilkan jalur ws yang perlu digunakan vless, trojan, socks, shadowsocks
vless_ws_path="/syra/`pwgen -csn 6 1 | xargs |sed 's/ /\//g'`"
trojan_ws_path="/syra/`pwgen -csn 6 1 | xargs |sed 's/ /\//g'`"
socks_ws_path="/syra/`pwgen -csn 6 1 | xargs |sed 's/ /\//g'`"
shadowsocks_ws_path="/syra/`pwgen -csn 6 1 | xargs |sed 's/ /\//g'`"

# 6. Gunakan gRPC untuk mengonfigurasi protokol vless, trojan, socks, shadowsocks 55 
# Secara acak menghasilkan jalur grpc yang perlu digunakan vless, trojan, socks, shadowsocks
vless_grpc_path="$(pwgen -1scn 12)$(pwgen -1scny -r "\!@#$%^&*()-+={}[]|:\";',/?><\`~" 36)"
trojan_grpc_path="$(pwgen -1scn 12)$(pwgen -1scny -r "\!@#$%^&*()-+={}[]|:\";',/?><\`~" 36)"
socks_grpc_path="$(pwgen -1scn 12)$(pwgen -1scny -r "\!@#$%^&*()-+={}[]|:\";',/?><\`~" 36)"
shadowsocks_grpc_path="$(pwgen -1scn 12)$(pwgen -1scny -r "\!@#$%^&*()-+={}[]|:\";',/?><\`~" 36)"

# 7. Buat direktori domainSock yang diperlukan dan otorisasi izin pengguna nginx
domainSock_dir="/run/v2ray";! [ -d $domainSock_dir ] && mkdir -pv $domainSock_dir
chown www-data.www-data $domainSock_dir

#8. Tentukan nama file domainSock yang perlu digunakan
vless_ws_domainSock="${domainSock_dir}/vless_ws.sock"
trojan_ws_domainSock="${domainSock_dir}/trojan_ws.sock"
vless_grpc_domainSock="${domainSock_dir}/vless_grpc.sock"
trojan_grpc_domainSock="${domainSock_dir}/trojan_grpc.sock"

# 9. Buat direktori secara acak untuk menyimpan sertifikat ssl berdasarkan waktu
ssl_dir="$(mkdir -pv "/etc/nginx/ssl/`date +"%F-%H-%M-%S"`" |awk -F"'" END'{print $2}')"

# Instal v2ray menggunakan perintah v2ray resmi dan ubah pengguna menjadi www-data dan muat ulang file layanan 75 
# 1. Perintah resmi untuk menginstal v2ray
curl -O https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh
curl -O https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-dat-release.sh
bash install-release.sh
bash install-dat-release.sh
# 2. Ubah izin direktori log v2ray ke www-data
chown -R www-data.www-data /var/log/v2ray
# 3. Ubah pengguna default v2ray ke www-data
sed -i '/User=nobody/cUser=www-data' /etc/systemd/system/v2ray.service
sed -i '/User=nobody/cUser=www-data' /etc/systemd/system/v2ray@.service
# 4. Muat ulang file layanan v2ray
systemctl daemon-reload


##Instal acme dan ajukan sertifikat enkripsi
source ~/.bashrc
if nc -z localhost 443;then /etc/init.d/nginx stop;fi
if ! [ -d /root/.acme.sh ];then curl https://get.acme.sh | sh;fi
~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
~/.acme.sh/acme.sh --issue -d "$domainName" -k ec-256 --alpn
~/.acme.sh/acme.sh --installcert -d "$domainName" --fullchainpath $ssl_dir/v2ray.crt --keypath $ssl_dir/v2ray.key --ecc
chown www-data.www-data $ssl_dir/v2ray.*

## Tambahkan perintah perbarui sertifikat ke tugas yang dijadwalkan
echo -n '#!/bin/bash
/etc/init.d/nginx stop
"/root/.acme.sh"/acme.sh --cron --home "/root/.acme.sh" &> /root/renew_ssl.log
/etc/init.d/nginx start
' > /usr/local/bin/ssl_renew.sh
chmod +x /usr/local/bin/ssl_renew.sh
if ! grep -q 'ssl_renew.sh' /var/spool/cron/crontabs/root;then (crontab -l;echo "15 03 */3 * * /usr/local/bin/ssl_renew.sh") | crontab;fi


# Konfigurasi nginx [80 blok layanan berikut sama sekali tidak diperlukan], jalankan perintah berikut untuk menambahkan file konfigurasi nginx
echo "
server {
	listen 80;
	server_name "$domainName";
	return 301 https://"'$host'""'$request_uri'";
}
server {
	listen 443 ssl http2;
	listen [::]:443 ssl http2;
	server_name "$domainName";
	ssl_certificate $ssl_dir/v2ray.crt;
	ssl_certificate_key $ssl_dir/v2ray.key;
	ssl_ciphers EECDH+CHACHA20:EECDH+CHACHA20-draft:EECDH+ECDSA+AES128:EECDH+aRSA+AES128:RSA+AES128:EECDH+ECDSA+AES256:EECDH+aRSA+AES256:RSA+AES256:EECDH+ECDSA+3DES:EECDH+aRSA+3DES:RSA+3DES:!MD5;
	ssl_protocols TLSv1.1 TLSv1.2 TLSv1.3;
	root /usr/share/nginx/html;

	# ------------------- Bagian konfigurasi WS dimulai -------------------
	location = "$vless_ws_path" {
		proxy_redirect off;
		proxy_pass http://unix:"${vless_ws_domainSock}";
		proxy_http_version 1.1;
		proxy_set_header Upgrade "'"$http_upgrade"'";
		proxy_set_header Connection '"'upgrade'"';
        	proxy_set_header Host "'"$host"'";
        	proxy_set_header X-Real-IP "'"$remote_addr"'";
        	proxy_set_header X-Forwarded-For "'"$proxy_add_x_forwarded_for"'";		
	}	
	
	location = "$trojan_ws_path" {
		proxy_redirect off;
		proxy_pass http://unix:"${trojan_ws_domainSock}";
		proxy_http_version 1.1;
		proxy_set_header Upgrade "'"$http_upgrade"'";
		proxy_set_header Connection '"'upgrade'"';
	        proxy_set_header Host "'"$host"'";
	        proxy_set_header X-Real-IP "'"$remote_addr"'";
	        proxy_set_header X-Forwarded-For "'"$proxy_add_x_forwarded_for"'";		
	}	
	
	location = "$socks_ws_path" {
		proxy_redirect off;
		proxy_pass http://127.0.0.1:"$socks_ws_port";
		proxy_http_version 1.1;
		proxy_set_header Upgrade "'"$http_upgrade"'";
		proxy_set_header Connection '"'upgrade'"';
	        proxy_set_header Host "'"$host"'";
	        proxy_set_header X-Real-IP "'"$remote_addr"'";
	        proxy_set_header X-Forwarded-For "'"$proxy_add_x_forwarded_for"'";		
	}
	
	location = "$shadowsocks_ws_path" {
		proxy_redirect off;
		proxy_pass http://127.0.0.1:"$shadowsocks_ws_port";
		proxy_http_version 1.1;
		proxy_set_header Upgrade "'"$http_upgrade"'";
		proxy_set_header Connection '"'upgrade'"';
	        proxy_set_header Host "'"$host"'";
	        proxy_set_header X-Real-IP "'"$remote_addr"'";
	        proxy_set_header X-Forwarded-For "'"$proxy_add_x_forwarded_for"'";	
	}	
	# ------------------- Akhir dari bagian konfigurasi WS -------------------

	# ------------------ Bagian konfigurasi gRPC dimula ------------------
	location ^~ "/$vless_grpc_path" {
		proxy_redirect off;
	  	grpc_set_header Host "'"$host"'";
	  	grpc_set_header X-Real-IP "'"$remote_addr"'";
	  	grpc_set_header X-Forwarded-For "'"$proxy_add_x_forwarded_for"'";
		grpc_pass grpc://unix:"${vless_grpc_domainSock}";		
	}
	
	location ^~ "/$trojan_grpc_path" {
		proxy_redirect off;
	  	grpc_set_header Host "'"$host"'";
	  	grpc_set_header X-Real-IP "'"$remote_addr"'";
	  	grpc_set_header X-Forwarded-For "'"$proxy_add_x_forwarded_for"'";
		grpc_pass grpc://unix:"${trojan_grpc_domainSock}";	
	}	
	
	location ^~ "/$socks_grpc_path" {
		proxy_redirect off;
	  	grpc_set_header Host "'"$host"'";
	  	grpc_set_header X-Real-IP "'"$remote_addr"'";
	  	grpc_set_header X-Forwarded-For "'"$proxy_add_x_forwarded_for"'";
		grpc_pass grpc://127.0.0.1:"$socks_grpc_port";	
	}
	
	location ^~ "/$shadowsocks_grpc_path" {
		proxy_redirect off;
	  	grpc_set_header Host "'"$host"'";
	  	grpc_set_header X-Real-IP "'"$remote_addr"'";
	  	grpc_set_header X-Forwarded-For "'"$proxy_add_x_forwarded_for"'";
		grpc_pass grpc://127.0.0.1:"$shadowsocks_grpc_port";		
	}	
	# ------------------ akhir bagian konfigurasi gRPC ------------------	

}
" > /etc/nginx/conf.d/v2ray.conf

# Konfigurasi v2ray, jalankan perintah berikut untuk menambahkan file konfigurasi v2ray
echo '
{
  "log" : {
    "access": "/var/log/v2ray/access.log",
    "error": "/var/log/v2ray/error.log",
    "loglevel": "warning"
  },
  "inbounds": [
	{
		"listen": '"\"${vless_ws_domainSock}\""',
		"protocol": "vless",
		"settings": {
			"decryption":"none",
			"clients": [
				{
				"id": '"\"$uuid\""',
				"level": 1
				}
			]
		},
		"streamSettings":{
			"network": "ws",
			"wsSettings": {
				"path": '"\"$vless_ws_path\""'
			}
		}
	},
	{
		"listen": '"\"$trojan_ws_domainSock\""',
		"protocol": "trojan",
		"settings": {
			"decryption":"none",		
			"clients": [
				{
					"password": '"\"$trojan_passwd\""',
					"email": "",
					"level": 0
				}
			],
			"udp": true
		},
		"streamSettings":{
			"network": "ws",
			"wsSettings": {
				"path": '"\"$trojan_ws_path\""'
			}
		}
	},
	{
		"listen": "127.0.0.1",
		"port": '"\"$socks_ws_port\""',
		"protocol": "socks",
		"settings": {
			"auth": "password",
			"accounts": [
				{
					"user": '"\"$socks_user\""',
					"pass": '"\"$socks_passwd\""'
				}
			],
			"level": 0,
			"udp": true
		},
		"streamSettings":{
			"network": "ws",
			"wsSettings": {
				"path": '"\"$socks_ws_path\""'
			}
		}
	},
	{
		"listen": "127.0.0.1",
		"port": '"\"$shadowsocks_ws_port\""',
		"protocol": "shadowsocks",
		"settings": {
			"decryption":"none",
			"email": "",
			"method": "AES-128-GCM",
			"password": '"\"$shadowsocks_passwd\""',
			"level": 0,
			"network": "tcp,udp",
			"ivCheck": false
		},
		"streamSettings":{
			"network": "ws",
			"wsSettings": {
				"path": '"\"$shadowsocks_ws_path\""'
			}
		}
	},
  	{
		"listen": '"\"${vless_grpc_domainSock}\""',
		"protocol": "vless",
		"settings": {
			"decryption":"none",
			"clients": [
				{
				"id": '"\"$uuid\""',
				"level": 0
				}
			]
		},
		"streamSettings":{
			"network": "grpc",
			"grpcSettings": {
				"serviceName": '"\"$vless_grpc_path\""'
			}
		}
	},
	{
		"listen": '"\"$trojan_grpc_domainSock\""',
		"protocol": "trojan",
		"settings": {
			"decryption":"none",
			"clients": [
				{
					"password": '"\"$trojan_passwd\""',
					"email": "",
					"level": 0
				}
			]
		},
		"streamSettings":{
		"network": "grpc",
			"grpcSettings": {
				"serviceName": '"\"$trojan_grpc_path\""'
			}
		}
	},
	{
		"listen": "127.0.0.1",
		"port": '"\"$socks_grpc_port\""',
		"protocol": "socks",
		"settings": {
			"decryption":"none",
			"auth": "password",
			"accounts": [
				{
					"user": '"\"$socks_user\""',
					"pass": '"\"$socks_passwd\""'
				}
			],
			"level": 0,
			"udp": true
		},
		"streamSettings":{
		"network": "grpc",
			"grpcSettings": {
				"serviceName": '"\"$socks_grpc_path\""'
			}
		}
	},
	{
		"listen": "127.0.0.1",
		"port": '"\"$shadowsocks_grpc_port\""',
		"protocol": "shadowsocks",
		"settings": {
			"decryption":"none",
			"email": "",
			"method": "AES-128-GCM",
			"password": '"\"$shadowsocks_passwd\""',
			"network": "tcp,udp",
			"ivCheck": false,
			"level": 0
		},
		"streamSettings":{
		"network": "grpc",
			"grpcSettings": {
				"serviceName": '"\"$shadowsocks_grpc_path\""'
			}
		}
	}	
  ],
  "routing": {
    "rules": [
      {
        "type": "field",
        "protocol": [
          "bittorrent"
        ],
        "outboundTag": "blocked"
      }
    ]
  },
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {}
    },
    {
      "tag": "blocked",
      "protocol": "blackhole",
      "settings": {}
    }
  ]
}
' > /usr/local/etc/v2ray/config.json

#perbesar hash bucket size ke 64 
sed -i 's/# server_names_hash_bucket_size 64;/server_names_hash_bucket_size 64;/g' /etc/nginx/nginx.conf

# Mulai ulang v2ray dan nginx
systemctl restart v2ray
systemctl status v2ray
/usr/sbin/nginx -t && systemctl restart nginx


# Keluarkan informasi konfigurasi dan simpan ke file
v2ray_config_info="/root/v2ray_config.info"
echo "
----------- Nama domain dan port terpadu untuk semua metode koneksi -----------
nama domain	: $domainName
Port		: 443

------------- WS ------------
-----------1. vless+ws -----------
Protokol	: vless
UUID		: $uuid
Path		: $vless_ws_path

-----------2. trojan+ws -----------
Protokol	: trojan
Katasandi	: $trojan_passwd
Path		: $trojan_ws_path

-----------3. socks+ws ------------
Protokol	: socks
Pengguna	：$socks_user	
Sandi	: $socks_passwd
Path	: $socks_ws_path

-------- 4. shadowsocks+ws ---------
Protokol	: shadowsocks
Sandi		: $shadowsocks_passwd
Enkripsi	：AES-128-GCM
Path	: $shadowsocks_ws_path

------------ gRPC -----------
------------5. vless+grpc -----------
Protokol	: vless
UUID		: $uuid
Path		: $vless_grpc_path
-----------6. trojan+grpc -----------
Protokol	: trojan
Sandi		: $trojan_passwd
Path		: $trojan_grpc_path
-----------7. socks+grpc ------------
Protokol	: socks
Pengguna	：$socks_user
Sandi		: $socks_passwd
Path		: $socks_grpc_path
--------8. shadowsocks+grpc ---------
Protokol	: shadowsocks
Sandi		: $shadowsocks_passwd
Enkripsi	：AES-128-GCM
Path	: $shadowsocks_grpc_path
" | tee $v2ray_config_info
