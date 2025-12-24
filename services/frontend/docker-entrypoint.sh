#!/bin/sh
set -e

# Substitute environment variables in nginx config
# This allows the same image to work in Docker/K8s/AKS/EKS
envsubst '${API_GATEWAY_URL}' < /etc/nginx/conf.d/default.conf.template > /etc/nginx/conf.d/default.conf

# Start nginx
exec nginx -g 'daemon off;'

