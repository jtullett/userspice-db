FROM mariadb:latest

LABEL description="UserSpice preconfigured database and files"
LABEL maintainer="Jon Tullett <jon.tullett@gmail.com>"
LABEL version="0.5"

# NB: leave USERSPICE_PASSWORD alone - it's like that to clarify shell substitution
ENV MYSQL_RANDOM_ROOT_PASSWORD=true
ENV MYSQL_DATABASE="userspice"
ENV USERSPICE_PASSWORD="$USERSPICE_PASSWORD"
ENV DATABASE_HOST="userspice"
ENV USERSPICE_INSTALL="/opt/UserSpice"
ENV USERSPICE_ROOT="/opt/www/UserSpice"

# Don't forget to escape the slash if you set the timezone
ENV TIMEZONE="Africa\/Johannesburg"

# Clone UserSpice
RUN true \
    && mkdir -p ${USERSPICE_INSTALL} \
    && mkdir -p ${USERSPICE_ROOT} \
    && chmod 0777 ${USERSPICE_ROOT} \
    && apt-get update > /dev/null \
    && apt-get install -y apt-utils git pwgen tzdata > /dev/null \
    && git clone https://github.com/mudmin/UserSpice4.git ${USERSPICE_INSTALL}

# Use local init.php not the incomplete one in the installer
COPY ./init.php ${USERSPICE_INSTALL}/users

# Set up the db credentials, db init scripts, and copy routine to populate volume directory
RUN true \
    && export USERSPICE_PASSWORD=`pwgen 20 1` \
    && sed -i "1s/^/USE userspice;\n/" ${USERSPICE_INSTALL}/install/install/includes/sql.sql \
    && cp ${USERSPICE_INSTALL}/install/install/includes/sql.sql /docker-entrypoint-initdb.d/userspice-tables.sql \
    && echo "CREATE USER 'userspice_admin'@'%' IDENTIFIED BY '${USERSPICE_PASSWORD}';" >> /docker-entrypoint-initdb.d/userspice-permissions.sql \
    && echo "GRANT SELECT, INSERT, UPDATE, DELETE ON \`userspice\`.* TO 'userspice_admin'@'%';" >> /docker-entrypoint-initdb.d/userspice-permissions.sql \
    && sed -i "s/HOSTNAME/${DATABASE_HOST}/" ${USERSPICE_INSTALL}/users/init.php \
    && sed -i "s/DATABASE/${MYSQL_DATABASE}/" ${USERSPICE_INSTALL}/users/init.php \
    && sed -i "s/PASSWORD/${USERSPICE_PASSWORD}/" ${USERSPICE_INSTALL}/users/init.php \
    && sed -i "s/TIMEZONE/${TIMEZONE}/" ${USERSPICE_INSTALL}/users/init.php \
    && sed -i 's/exec "$@"//' /usr/local/bin/docker-entrypoint.sh \
    && echo "echo 'Copying UserSpice files'" >> /usr/local/bin/docker-entrypoint.sh \
    && echo "cp -R $USERSPICE_INSTALL/* $USERSPICE_ROOT" >> /usr/local/bin/docker-entrypoint.sh \
    && echo 'exec "$@"' >> /usr/local/bin/docker-entrypoint.sh \
    && apt-get remove -y git

# Standard MySQL port
EXPOSE 3306

# Declare the UserSpice volume
VOLUME ${USERSPICE_ROOT}

