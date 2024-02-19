#!/bin/bash
# Copyright (c) 2022-2024, AllWorldIT.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to
# deal in the Software without restriction, including without limitation the
# rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
# sell copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
# IN THE SOFTWARE.


fdc_notice "Setting up VaultWarden permissions"
# Make sure our data directory perms are correct
chown root:vaultwarden /var/lib/vaultwarden
chmod 0770 /var/lib/vaultwarden
# Set permissions on VaultWarden configuration
chown root:vaultwarden /etc/vaultwarden
chmod 0750 /etc/vaultwarden


fdc_notice "Initializing VaultWarden settings"

if [ -n "$VAULTWARDEN_ADMIN_TOKEN" ]; then
	# shellcheck disable=SC2016
	if ! echo "$VAULTWARDEN_ADMIN_TOKEN" | grep -q 'argon2'; then
		fdc_error "Environment variable 'VAULTWARDEN_ADMIN_TOKEN' is not encrypted!"
		false
	fi
fi

# Work out database details
case "$VAULTWARDEN_DATABASE_TYPE" in
	mariadb|mysql)
		if [ -z "$MYSQL_DATABASE" ]; then
			fdc_error "Environment variable 'MYSQL_DATABASE' is required"
			false
		fi
		# Check for a few things we need
		if [ -z "$MYSQL_HOST" ]; then
			fdc_error "Environment variable 'MYSQL_HOST' is required"
			false
		fi
		if [ -z "$MYSQL_USER" ]; then
			fdc_error "Environment variable 'MYSQL_USER' is required"
			false
		fi
		if [ -z "$MYSQL_PASSWORD" ]; then
			fdc_error "Environment variable 'MYSQL_PASSWORD' is required"
			false
		fi
		database_type=mysql
		database_host=$MYSQL_HOST
		database_name=$MYSQL_DATABASE
		database_username=$MYSQL_USER
		database_password=$MYSQL_PASSWORD
		;;

	postgresql)
		# Check for a few things we need
		if [ -z "$POSTGRES_DATABASE" ]; then
			fdc_error "Environment variable 'POSTGRES_DATABASE' is required"
			false
		fi
		if [ -z "$POSTGRES_HOST" ]; then
			fdc_error "Environment variable 'POSTGRES_HOST' is required"
			false
		fi
		if [ -z "$POSTGRES_USER" ]; then
			fdc_error "Environment variable 'POSTGRES_USER' is required"
			false
		fi
		if [ -z "$POSTGRES_PASSWORD" ]; then
			fdc_error "Environment variable 'POSTGRES_PASSWORD' is required"
			false
		fi
		database_type=postgresql
		database_host=$POSTGRES_HOST
		database_name=$POSTGRES_DATABASE
		database_username=$POSTGRES_USER
		database_password=$POSTGRES_PASSWORD
		;;

	sqlite)
		export VAULTWARDEN_DATABASE_URL=/var/lib/vaultwarden/vaultwarden.db
		;;

	*)
		# If we're running in FDC_CI mode, we can just skip the error as we default to 'dev-file'
		if [ -n "$FDC_CI" ]; then
			fdc_warn "Running with database 'dev-file' as 'VAULTWARDEN_DATABASE_TYPE' is not set"
		else
			fdc_error "Environment variable 'VAULTWARDEN_DATABASE_TYPE' must be set."
			false
		fi
		;;
esac

# If we have a datbase type set, export the environment to VaultWarden
if [ -n "$database_type" ]; then
	export VAULTWARDEN_DB_CONNECTION_RETRIES=0
	export VAULTWARDEN_DATABASE_URL="$database_type://$database_username:$database_password@$database_host/$database_name"
fi

# Allow overrding of the data folder
export VAULTWARDEN_DATA_FOLDER=${VAULTWARDEN_DATA_FOLDER:-/var/lib/vaultwarden}
# Allow overriding enabling websockets
export VAULTWARDEN_WEBSOCKET_ENABLED=${VAULTWARDEN_WEBSOCKET_ENABLED:-true}
# Set the web vault folder
export VAULTWARDEN_WEB_VAULT_FOLDER=/usr/local/share/vaultwarden-web
# Set the listen port to 8080
export VAULTWARDEN_ROCKET_ADDRESS=${VAULTWARDEN_ROCKET_ADDRESS:-::}
export VAULTWARDEN_ROCKET_PORT=8080


# Write out environment and fix perms of the config file

set | grep -E '^VAULTWARDEN_' | sed -e 's/^VAULTWARDEN_//' > /etc/vaultwarden/vaultwarden.env || true
chown root:vaultwarden /etc/vaultwarden/vaultwarden.env
chmod 0640 /etc/vaultwarden/vaultwarden.env
