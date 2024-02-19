#!/bin/bash

# Default to the sqlite database type for tests run without any environment variables
if [ -z "$VAULTWARDEN_DATABASE_TYPE" ]; then
    export VAULTWARDEN_DATABASE_TYPE=sqlite
    export VAULTWARDEN_I_REALLY_WANT_VOLATILE_STORAGE=true
fi

# Set up admin token
TOKEN=$(openssl rand -base64 48)
TOKEN_SALT=$(openssl rand -base64 8)
VAULTWARDEN_ADMIN_TOKEN=$(echo -n "$TOKEN" | argon2 "$TOKEN_SALT" -e)
export VAULTWARDEN_ADMIN_TOKEN

fdc_notice "CI/CD Admin token is: $TOKEN"
