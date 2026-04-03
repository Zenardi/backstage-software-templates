#!/bin/sh

echo "Starting Nginx..."
nginx -g 'daemon off;' &
NGINX_PID=$!

echo "Starting Metrics Server..."
node src/metrics-server.mjs &
METRICS_PID=$!

# Wait for both processes
wait $NGINX_PID $METRICS_PID
