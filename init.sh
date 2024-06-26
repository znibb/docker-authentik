#!/bin/bash
if [ ! -f .env ]; then
	cp -v files/.env.example .env
fi