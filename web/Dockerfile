FROM debian:12-slim

RUN apt-get update -qq && \
    apt-get install -y apache2 --no-install-recommends && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Ocultar firmas del servidor
RUN echo 'ServerTokens Prod' >> /etc/apache2/apache2.conf && \
    echo 'ServerSignature Off' >> /etc/apache2/apache2.conf

# Crear usuario no-root para Apache
RUN useradd -r -s /bin/false webuser && \
    chown -R webuser:webuser /var/www/html /var/log/apache2

RUN sed -i 's/APACHE_RUN_USER=www-data/APACHE_RUN_USER=webuser/' /etc/apache2/envvars && \
    sed -i 's/APACHE_RUN_GROUP=www-data/APACHE_RUN_GROUP=webuser/' /etc/apache2/envvars

# Activar autoindex para que /ftp-files/ liste archivos reales
RUN a2enmod autoindex

# Alias /ftp-files/ apuntando a una subcarpeta del volumen compartido
RUN printf 'Alias /ftp-files /var/www/html/ftp-files\n\
<Directory /var/www/html/ftp-files>\n\
    Options Indexes FollowSymLinks\n\
    AllowOverride None\n\
    Require all granted\n\
    IndexOptions FancyIndexing NameWidth=* HTMLTable\n\
</Directory>\n' > /etc/apache2/conf-available/ftp-files.conf && \
    a2enconf ftp-files

COPY html/ /var/www/html/
RUN chown -R webuser:webuser /var/www/html

EXPOSE 80
CMD ["apachectl", "-D", "FOREGROUND"]
