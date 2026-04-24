FROM debian:12

RUN apt-get update -qq && \
    apt-get install -y vsftpd passwd procps \
                       iproute2 util-linux --no-install-recommends && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Copiar tus scripts
COPY scripts/ /opt/ftp-admin/
RUN chmod +x /opt/ftp-admin/*.sh

# Estructura de directorios FTP
RUN mkdir -p /home/ftp/LocalUser /home/ftp/public && \
    chown root:root /home/ftp && chmod 755 /home/ftp

RUN cat > /etc/vsftpd.conf << 'EOF'
listen=YES
listen_ipv6=NO

anonymous_enable=NO
local_enable=YES
write_enable=YES

dirmessage_enable=YES
use_localtime=YES
xferlog_enable=YES
connect_from_port_20=YES

secure_chroot_dir=/home/ftp/LocalUser

pam_service_name=vsftpd

rsa_cert_file=/etc/ssl/certs/ssl-cert-snakeoil.pem
rsa_private_key_file=/etc/ssl/private/ssl-cert-snakeoil.key
ssl_enable=NO

pasv_enable=YES
pasv_min_port=21100
pasv_max_port=21110
pasv_address=127.0.0.1

chroot_local_user=YES
allow_writeable_chroot=YES
EOF

EXPOSE 21 21100-21110

# vsftpd en segundo plano; el menú se corre con docker exec -it
CMD ["bash", "-c", "vsftpd /etc/vsftpd.conf & tail -f /dev/null"]
