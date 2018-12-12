# Provision WordPress Develop

# Make a database, if we don't already have one
echo -e "\nCreating database 'wordpress_commit' (if it's not already there)"
mysql -u root --password=root -e "CREATE DATABASE IF NOT EXISTS wordpress_commit"
mysql -u root --password=root -e "GRANT ALL PRIVILEGES ON wordpress_commit.* TO wp@localhost IDENTIFIED BY 'wp';"
echo -e "\n DB operations done.\n\n"

# Make a database, if we don't already have one
echo -e "\nCreating database 'wpcommit_unit_tests' (if it's not already there)"
mysql -u root --password=root -e "CREATE DATABASE IF NOT EXISTS wpcommit_unit_tests"
mysql -u root --password=root -e "GRANT ALL PRIVILEGES ON wpcommit_unit_tests.* TO wp@localhost IDENTIFIED BY 'wp';"
echo -e "\n DB operations done.\n\n"

# Nginx Logs
mkdir -p ${VVV_PATH_TO_SITE}/log
touch ${VVV_PATH_TO_SITE}/log/src.error.log
touch ${VVV_PATH_TO_SITE}/log/src.access.log
touch ${VVV_PATH_TO_SITE}/log/build.access.log
touch ${VVV_PATH_TO_SITE}/log/build.access.log

# Checkout, install and configure WordPress trunk via develop.svn
if [[ ! -d "${VVV_PATH_TO_SITE}/public_html" ]]; then
  echo "Checking out WordPress trunk. See https://develop.svn.wordpress.org/trunk"
  noroot svn checkout "https://develop.svn.wordpress.org/trunk/" "/tmp/wordpress-commit"

  cd /tmp/wordpress-commit/src/

  echo "Installing local npm packages for src.wordpress-commit.test, this may take several minutes."
  noroot npm install

  echo "Initializing grunt and creating build.wordpress-commit.test, this may take several minutes."
  noroot grunt

  echo "Moving WordPress commit to a shared directory, ${VVV_PATH_TO_SITE}/public_html"
  mv /tmp/wordpress-commit ${VVV_PATH_TO_SITE}/public_html

  cd ${VVV_PATH_TO_SITE}/public_html/src/
  echo "Creating wp-config.php for src.wordpress-commit.test and build.wordpress-commit.test."
  noroot wp core config --dbname=wordpress_commit --dbuser=wp --dbpass=wp --quiet --extra-php <<PHP
// Match any requests made via xip.io.
if ( isset( \$_SERVER['HTTP_HOST'] ) && preg_match('/^(src|build)(.wordpress-commit.)\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}(.xip.io)\z/', \$_SERVER['HTTP_HOST'] ) ) {
    define( 'WP_HOME', 'http://' . \$_SERVER['HTTP_HOST'] );
    define( 'WP_SITEURL', 'http://' . \$_SERVER['HTTP_HOST'] );
} else if ( 'build' === basename( dirname( __FILE__ ) ) ) {
// Allow (src|build).wordpress-commit.test to share the same Database
    define( 'WP_HOME', 'http://build.wordpress-commit.test' );
    define( 'WP_SITEURL', 'http://build.wordpress-commit.test' );
}

define( 'WP_DEBUG', true );
PHP

  echo "Installing src.wordpress-commit.test."
  noroot wp core install --url=src.wordpress-commit.test --quiet --title="WordPress Commit" --admin_name=admin --admin_email="admin@local.test" --admin_password="password"
  cp /srv/config/wordpress-config/wp-tests-config.php ${VVV_PATH_TO_SITE}/public_html/
  cd ${VVV_PATH_TO_SITE}/public_html/

else

  echo "Updating WordPress commit..."
  cd ${VVV_PATH_TO_SITE}/public_html/
  if [[ -e .svn ]]; then
    svn up
  else

    if [[ $(git rev-parse --abbrev-ref HEAD) == 'master' ]]; then
      git pull --no-edit git://develop.git.wordpress.org/ master
    else
      echo "Skip auto git pull on develop.git.wordpress.org since not on master branch"
    fi

  fi

  echo "Updating npm packages..."
  noroot npm install &>/dev/null
fi

if [[ ! -d "${VVV_PATH_TO_SITE}/public_html/build" ]]; then
  echo "Initializing grunt in WordPress develop... This may take a few moments."
  cd ${VVV_PATH_TO_SITE}/public_html/
  grunt
fi
