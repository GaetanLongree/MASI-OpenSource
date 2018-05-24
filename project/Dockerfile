FROM drupal:7
RUN apt-get update && apt-get install -y libldap2-dev && rm -rf /var/lib/apt/lists/*
RUN docker-php-ext-configure ldap --with-libdir=lib/x86_64-linux-gnu/ \
   && docker-php-ext-install ldap
RUN cp -R /var/www/html /tmp
VOLUME /var/www/html

COPY entrypoint.sh /

ENTRYPOINT [ "bash", "/entrypoint.sh" ]
CMD ["apache2-foreground"]