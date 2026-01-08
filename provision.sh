echo '==> Updating Debian repositories'

apt-get -q=2 update

apt-get -q=2 install --reinstall tzdata &>/dev/null
timedatectl set-timezone $TIMEZONE

echo '==> Setting '$(timedatectl show | grep Timezone)

echo '==> Installing Linux tools'

cp /vagrant/config/bash_aliases /home/vagrant/.bash_aliases
chown vagrant:vagrant /home/vagrant/.bash_aliases
apt-get -q=2 install software-properties-common apt-transport-https tree zip unzip pv whois &>/dev/null

echo '==> Installing Git'

apt-get -q=2 install git &>/dev/null

echo '==> Installing Apache'

apt-get -q=2 install apache2 apache2-utils &>/dev/null
apt-get -q=2 update
cp /vagrant/config/localhost.conf /etc/apache2/conf-available/localhost.conf
cp /vagrant/config/virtualhost.conf /etc/apache2/sites-available/virtualhost.conf
sed -i 's|GUEST_SYNCED_FOLDER|'$GUEST_SYNCED_FOLDER'|' /etc/apache2/sites-available/virtualhost.conf
sed -i 's|FORWARDED_PORT_80|'$FORWARDED_PORT_80'|' /etc/apache2/sites-available/virtualhost.conf
a2enconf localhost &>/dev/null
a2enmod rewrite vhost_alias &>/dev/null
a2ensite virtualhost &>/dev/null

echo '==> Setting MariaDB 11.8 repository'

mkdir -p /etc/apt/keyrings
curl -sSLo /etc/apt/keyrings/mariadb-keyring.pgp https://mariadb.org/mariadb_release_signing_key.pgp
cp /vagrant/config/mariadb.sources /etc/apt/sources.list.d/mariadb.sources
apt-get -q=2 update

echo '==> Installing MariaDB'

DEBIAN_FRONTEND=noninteractive apt-get -q=2 install mariadb-server &>/dev/null

echo '==> Setting PHP 8.4 repository'

curl -sSLo /tmp/debsuryorg-archive-keyring.deb https://packages.sury.org/debsuryorg-archive-keyring.deb
dpkg -i /tmp/debsuryorg-archive-keyring.deb &>/dev/null
cp /vagrant/config/php.list /etc/apt/sources.list.d/php.list
apt-get -q=2 update

echo '==> Installing PHP'

apt-get -q=2 install php8.4 php-pear php8.4-cli libapache2-mod-php8.4 libphp8.4-embed \
    php8.4-bcmath php8.4-bz2 php8.4-curl php8.4-fpm php8.4-gd php8.4-imap php8.4-intl \
    php8.4-mbstring php8.4-mysql php8.4-mysqlnd php8.4-pgsql php8.4-pspell php8.4-readline \
    php8.4-soap php8.4-sqlite3 php8.4-tidy php8.4-xdebug php8.4-xml php8.4-xmlrpc php8.4-yaml php8.4-zip &>/dev/null
a2dismod mpm_event &>/dev/null
a2enmod mpm_prefork &>/dev/null
a2enmod php8.4 &>/dev/null
cp /vagrant/config/php.ini.htaccess /var/www/.htaccess
PHP_ERROR_REPORTING_INT=$(php -r 'echo '"$PHP_ERROR_REPORTING"';')
sed -i 's|PHP_ERROR_REPORTING_INT|'$PHP_ERROR_REPORTING_INT'|' /var/www/.htaccess

echo '==> Installing Adminer'

if [ ! -d /usr/share/adminer ]; then
    mkdir -p /usr/share/adminer/adminer-plugins
    curl -LsS https://www.adminer.org/latest-en.php -o /usr/share/adminer/latest-en.php
    curl -LsS https://raw.githubusercontent.com/vrana/adminer/master/plugins/login-password-less.php -o /usr/share/adminer/adminer-plugins/login-password-less.php
    curl -LsS https://raw.githubusercontent.com/vrana/adminer/master/plugins/dump-json.php -o /usr/share/adminer/adminer-plugins/dump-json.php
    curl -LsS https://raw.githubusercontent.com/vrana/adminer/master/plugins/pretty-json-column.php -o /usr/share/adminer/adminer-plugins/pretty-json-column.php
    curl -LsS https://raw.githubusercontent.com/vrana/adminer/master/designs/nicu/adminer.css -o /usr/share/adminer/adminer.css
fi
cp /vagrant/config/adminer.php /usr/share/adminer/adminer.php
cp /vagrant/config/adminer-plugins.php /usr/share/adminer/adminer-plugins.php
cp /vagrant/config/adminer.conf /etc/apache2/conf-available/adminer.conf
sed -i 's|FORWARDED_PORT_80|'$FORWARDED_PORT_80'|' /etc/apache2/conf-available/adminer.conf
a2enconf adminer &>/dev/null

echo '==> Installing NPM and Node.js'

DEBIAN_FRONTEND=noninteractive apt-get -q=2 install npm &>/dev/null

echo '==> Testing Apache configuration'

apache2ctl configtest

echo '==> Starting Apache'

service apache2 restart

echo '==> Starting MariaDB'

service mariadb restart
mariadb-admin -u root password ""

echo '==> Cleaning apt cache'

apt-get -q=2 autoclean
apt-get -q=2 autoremove

echo
echo '==> Stack versions <=='

lsb_release -d | cut -f 2
openssl version
curl --version | head -n1 | cut -d '(' -f 1
git --version
apache2 -v | head -n1 | cut -d ' ' -f 3
mariadb -V
php -v | head -n1
python3 --version
echo npm $(npm -v)
echo node.js $(nodejs -v)
