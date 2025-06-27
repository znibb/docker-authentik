#!/bin/bash
if [ ! -f .env ]; then
	cp -v files/.env.example .env
fi

mkdir -p ./data/certs
mkdir -p ./data/custom-templates
mkdir -p ./data/media/public