FROM httpd:latest
WORKDIR /usr/local/apache2/htdocs
COPY ./index.html /usr/local/apache2/htdocs/
COPY ./indexone.html /usr/local/apache2/htdocs/