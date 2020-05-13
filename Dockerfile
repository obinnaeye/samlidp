FROM richarvey/nginx-php-fpm:1.7.1

RUN apk update && apk add openssl rsyslog rsyslog-tls php7-pdo_pgsql postgresql-dev  && rm -rf /var/cache/apk/*

ADD conf/credentials/wildcard_certificate.crt conf/credentials/wildcard_certificate.key.enc /etc/pki/
ADD app/composer.json /app/

# build and config symfony app
RUN cd /app && php -d memory_limit=-1 /usr/bin/composer install --no-autoloader --no-interaction --no-scripts --no-dev
ADD conf/nginx/nginx-site.conf /etc/nginx/sites-available/default.conf

ADD app /app
RUN mkdir /app/var
RUN cd /app && php -d memory_limit=-1 /usr/bin/composer update --optimize-autoloader --no-interaction
RUN mkdir -p /app/web/images/idp_logo /app/web/uploads/tmp && chown -Rf nginx /app/var /app/web/images/idp_logo /app/web/uploads

RUN mkdir /app/vendor/simplesamlphp/simplesamlphp/cert && chown nginx /app/vendor/simplesamlphp/simplesamlphp/cert
ADD conf/credentials/attributes* /app/vendor/simplesamlphp/simplesamlphp/cert/
  
RUN chown -R nginx /app/vendor/simplesamlphp/simplesamlphp/cert

RUN cd /app/vendor/simplesamlphp/simplesamlphp/ && sed -i.bak '/ext-pdo_sqlite/d' composer.json && composer config repositories.simplesamlphp/simplesamlphp-module-entitycategories vcs https://github.com/sitya/simplesamlphp-module-entitycategories.git && composer require --update-no-dev simplesamlphp/simplesamlphp-module-entitycategories:dev-master
ADD conf/simplesamlphp/authsources.php conf/simplesamlphp/config.php /app/vendor/simplesamlphp/simplesamlphp/config/
ADD conf/simplesamlphp/saml20-idp-hosted.php conf/simplesamlphp/saml20-sp-remote.php /app/vendor/simplesamlphp/simplesamlphp/metadata/
ADD conf/simplesamlphp/saml20-idp-hosted.php /app/vendor/simplesamlphp/simplesamlphp/metadata/saml20-idp-remote.php
# COPY conf/simplesamlphp/metadata.php /app/vendor/simplesamlphp/simplesamlphp/www/saml2/idp/metadata.php // Only used this for debugging metadata.php
ADD conf/simplesamlphp/name2oid.php conf/simplesamlphp/oid2name.php /app/vendor/simplesamlphp/simplesamlphp/attributemap/
ADD misc/themesamlidpio /app/vendor/simplesamlphp/simplesamlphp/modules/themesamli
ADD misc/SQL.php /app/vendor/simplesamlphp/simplesamlphp/modules/sqlauth/lib/Auth/Source/SQL.php
ADD misc/attributes/* /var/www/html/
ADD conf/simplesamlphp/enable /app/vendor/simplesamlphp/simplesamlphp/modules/sqlauth/enable
ADD conf/simplesamlphp/enable /app/vendor/simplesamlphp/simplesamlphp/modules/consent/enable

# rsyslog stuff
ADD conf/rsyslog/rsyslog.conf /etc/
ADD conf/rsyslog/10-simplesamlphp.conf /etc/rsyslog.d/
ADD misc/rsyslog-start.sh /rsyslog-start.sh
ADD misc/samlidp-start.sh /samlidp-start.sh

# For fast building of the docker image during development, you may uncomment this. Then you need to copy
# app/src to the project root (samlidp: depending on what you called yours). You can as well do same for 
# some other directories where you frequently make changes.
# Remember to copy your changes to changes back to app/src when you're ready to commit
# COPY src /app/src

# cron for backend mode
ADD conf/backend-crontab /var/spool/cron/crontabs/root

RUN echo "error_reporting = E_ALL & ~E_NOTICE & ~E_WARNING" >> /usr/local/etc/php-fpm.conf
RUN echo "error_reporting = E_ALL & ~E_NOTICE & ~E_WARNING" >> /usr/local/etc/php/conf.d/php.ini

CMD ["/samlidp-start.sh"]
