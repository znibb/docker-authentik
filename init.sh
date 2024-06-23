#!/bin/bash
if [ ! -f .env ]; then
	cp -v files/.env.example .env
fi
if [ ! -f ./secrets/AUTHENTIK_SECRET_KEY.secret ]; then
    touch ./secrets/AUTHENTIK_SECRET_KEY.secret
    echo "Creating ./secrets/AUTHENTIK_SECRET_KEY.secret"
fi
if [ ! -f ./secrets/POSTGRES_PASSWORD.secret ]; then
    touch ./secrets/POSTGRES_EMAIL_PASSWORD.secret
    echo "Creating ./secrets/POSTGRES_EMAIL_PASSWORD.secret"
fi