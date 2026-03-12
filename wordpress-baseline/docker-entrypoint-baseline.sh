#!/usr/bin/env bash

# Check for shib keys.
set +u
if [ -n "$SHIB_SP_KEY" ] && [ -n "$SHIB_SP_CERT" ] ; then
  SHIB_PK_AND_CERT_PROVIDED='true'
fi

WORDPRESS_CONF='/etc/apache2/sites-enabled/wordpress.conf'
SHIBBOLETH_CONF='/etc/apache2/sites-available/shibboleth.conf'
S3PROXY_CONF='/etc/apache2/sites-available/s3proxy.conf'

# Paves over the shibboleth.xml file with a copy of the shibboleth2-template.xml file with the placeholder
# values replaced with the real values that should be available now as environment variables.
editShibbolethXML() {

  echo "editShibbolethXML..."

  # Write out the pem file environment variables as files to the same directory as shibboleth2.xml.
  echo -n "$SHIB_SP_KEY" > /etc/shibboleth/sp-key.pem
  echo -n "$SHIB_SP_CERT" > /etc/shibboleth/sp-cert.pem

  insertSpEntityId() { sed "s|SP_ENTITY_ID_PLACEHOLDER|$SP_ENTITY_ID|g" < /dev/stdin; }

  insertIdpEntityId() { sed "s|IDP_ENTITY_ID_PLACEHOLDER|$IDP_ENTITY_ID|g" < /dev/stdin; }

  cat /etc/shibboleth/shibboleth2-template.xml \
    | insertSpEntityId \
    | insertIdpEntityId \
  > /etc/shibboleth/shibboleth2.xml
}

# Put the correct logout url into the shibboleth.conf file
editShibbolethConf() {

  echo "editShibbolethConf..."
  
  sed -i "s|SHIB_IDP_LOGOUT_PLACEHOLDER|$SHIB_IDP_LOGOUT|g" /etc/apache2/sites-available/shibboleth.conf
}

# Generate a shibboleth idp metadata file if one does not already exist.
getIdpMetadataFile() {
  echo "getIdpMetadataFile..."
  local xmlfile=/etc/shibboleth/idp-metadata.xml
  if [ ! -f $xmlfile ] ; then
    curl $IDP_ENTITY_ID -o $xmlfile
  fi
}

# Add buPrincipleNameID (BUID) as an attribute to extract from SAML assertions returned back from the IDP. 
modifyAttributesFile() {
  # Disable this for now:
  return 0

  echo "modifyAttributesFile..."
  local find="<\/Attributes>"
  local insertBefore="    <Attribute name=\"urn:oid:1.3.6.1.4.1.9902.2.1.9\" id=\"buPrincipalNameID\"/>"
  local xmlfile="/etc/shibboleth/attribute-map.xml"
  sed -i "/${find}/i\ ${insertBefore}" ${xmlfile}
}

# Duplicate the wordpress.conf with as a new virtual host (different ServerName directive) with added shibboleth configurations. 
setVirtualHost() {
  echo "setVirtualHost..."

  sed -i "s|localhost|${SERVER_NAME:-"localhost"}|g" $WORDPRESS_CONF

  sed -i "s|UTC|${TZ:-"UTC"}|g" $WORDPRESS_CONF
}

# Look for an indication the last step of initialization was run or not.
uninitialized_baseline() {
  [ -n "$(grep 'localhost' $WORDPRESS_CONF)" ] && true || false
}

MU_PLUGIN_LOADER='/var/www/html/wp-content/mu-plugins/loader.php'
check_mu_plugin_loader() {
  if [ -f $MU_PLUGIN_LOADER ] ; then
    echo "mu_plugin_loader already generated..."
  else
    echo "generate_mu_plugin_loader..."
    wp bu-core generate-mu-plugin-loader \
      --path=/var/www/html \
      --require=/var/www/html/wp-content/mu-plugins/bu-core/src/wp-cli.php
  fi
}

check_wordpress_install() {

    if ! wp core is-installed 2>/dev/null; then
      # WP is not installed. Let's try installing it.
      echo "installing multisite..."
      wp core multisite-install --title="local root site" \
        --url="http://${SERVER_NAME:-localhost}" \
        --admin_user="admin" \
        --admin_email="no-use-admin@bu.edu"

      else
        # WP is already installed.
        echo "WordPress is already installed. No need to create a new database."
    fi
}

setup_redis() {
  # If there is a REDIS_HOST and REDIS_PORT available in the environment, add them as wp config values.
  if [ -n "${REDIS_HOST:-}" ] && [ -n "${REDIS_PORT:-}" ] ; then
    echo "Redis host detected, setting up Redis..."
    wp config set WP_REDIS_HOST $REDIS_HOST --add --type=constant
    wp config set WP_REDIS_PORT $REDIS_PORT --add --type=constant

    # If there is a REDIS_PASSWORD available in the environment, add it as a wp config value.
    if [ -n "${REDIS_PASSWORD:-}" ] ; then
      wp config set WP_REDIS_PASSWORD $REDIS_PASSWORD --add --type=constant
    fi

    # If the redis-cache plugin is available, create the object-cache.php file and network activate the plugin.
    if wp plugin is-installed redis-cache ; then
      echo "redis-cache plugin detected, setting up object cache..."
      wp plugin activate redis-cache
      wp redis update-dropin
    fi

  fi
}

# Append an include statement for shibboleth.conf as a new line in wordpress.conf directly below a placeholder.
includeShibbolethConfig() {
  sed -i 's|# SHIBBOLETH_PLACEHOLDER|Include '${SHIBBOLETH_CONF}'|' $WORDPRESS_CONF
}

# Replace a placeholder in s3proxy.conf with the actual s3proxy host value.
setS3ProxyHost() {
  echo "setS3ProxyHost..."
  sed -i 's|S3PROXY_HOST_PLACEHOLDER|'$S3PROXY_HOST'|g' $S3PROXY_CONF
}

# Append an include statement for s3proxy.conf as a new line in wordpress.conf directly below a placeholder.
includeS3ProxyConfig() {
  echo "includeS3ProxyConfig..."
  sed -i 's|# PROXY_PLACEHOLDER|Include '${S3PROXY_CONF}'|' $WORDPRESS_CONF
}


# Setup xdebug if the XDEBUG environment variable is set to 'true'.
# This is currently customized for use with local docker and may be macOS specific.
# Xdebug version compatibility: https://xdebug.org/docs/compat
setup_xdebug() {
  if [ "${XDEBUG:-}" == 'true' ] ; then
    # Detect PHP version to install compatible xdebug
    PHP_VERSION=$(php -r 'echo PHP_VERSION;')
    PHP_MAJOR_MINOR=$(echo $PHP_VERSION | cut -d. -f1-2)
    
    # Map PHP version to compatible xdebug version based on official compatibility table
    case "$PHP_MAJOR_MINOR" in
      7.2|7.3|7.4)
        # PHP 7.2-7.4: Xdebug 3.1.x is the last version supporting PHP 7.x
        XDEBUG_VERSION="3.1.6"
        ;;
      8.0|8.1)
        # PHP 8.0-8.1: Xdebug 3.1.x still works, using for consistency
        XDEBUG_VERSION="3.1.6"
        ;;
      8.2|8.3)
        # PHP 8.2-8.3: Xdebug 3.3.x is stable and well-tested
        XDEBUG_VERSION="3.3.2"
        ;;
      8.4|8.5)
        # PHP 8.4+: Use latest xdebug 3.4.x
        XDEBUG_VERSION=""  # Let PECL pick the latest
        ;;
      *)
        # Unknown PHP version: try latest
        echo "Warning: Unknown PHP version $PHP_MAJOR_MINOR, attempting latest xdebug..."
        XDEBUG_VERSION=""
        ;;
    esac
    
    # Check if xdebug is already installed (any version)
    if [ -z "$(pecl list | grep xdebug)" ] ; then
      if [ -n "$XDEBUG_VERSION" ]; then
        echo "Installing xdebug $XDEBUG_VERSION for PHP $PHP_MAJOR_MINOR..."
        pecl install xdebug-$XDEBUG_VERSION
      else
        echo "Installing latest xdebug for PHP $PHP_MAJOR_MINOR..."
        pecl install xdebug
      fi
    else
      echo "Xdebug already installed: $(pecl list | grep xdebug)"
    fi
    
    docker-php-ext-enable xdebug
    echo 'xdebug.start_with_request=yes' >> /usr/local/etc/php/php.ini
    echo 'xdebug.mode=debug' >> /usr/local/etc/php/php.ini
    echo 'xdebug.client_host="host.docker.internal"' >> /usr/local/etc/php/php.ini
  fi
}


if [ "${SHELL:-}" == 'true' ] ; then
  # Keeps the container running, but apache is not started.
  tail -f /dev/null
else

  check_wordpress_install

  check_mu_plugin_loader

  setup_redis

  # Configure S3 proxy if the config values are provided (assumes that if the bucket name is provided, the other config values are as well).
  if [ -n "${S3PROXY_HOST}" ]; then
    setS3ProxyHost

    includeS3ProxyConfig
  fi

  ## XDebug should not be enabled in production environments.
  ## It is only intended for local development environments.
  setup_xdebug

  if uninitialized_baseline ; then

    if [ -n "$SHIB_PK_AND_CERT_PROVIDED" ] ; then

      editShibbolethXML

      editShibbolethConf

      getIdpMetadataFile

      modifyAttributesFile

      includeShibbolethConfig

      echo 'shibd start...'
      service shibd start
    fi

    setVirtualHost
  fi
fi