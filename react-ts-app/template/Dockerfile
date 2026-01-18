# Stage 1: Build the application
FROM node:20-alpine AS build
WORKDIR /app

# Copy package configuration and install dependencies
COPY package.json package-lock.json ./
RUN npm install

# Copy the rest of the application source code
COPY . .

# Build the project
RUN npm run build

# Stage 2: Serve the application with Nginx and metrics server
FROM node:20-alpine

# Install nginx
RUN apk add --no-cache nginx

# Copy the built assets from the build stage
COPY --from=build /app/dist /usr/share/nginx/html

# Copy metrics server files
COPY --from=build /app/src/metrics-server.mjs ./src/
COPY --from=build /app/package.json /app/package-lock.json ./
RUN npm install --production

# Add a custom Nginx configuration to support client-side routing
COPY nginx.conf /etc/nginx/nginx.conf

# Copy startup script
COPY start.sh /app/start.sh
RUN chmod +x /app/start.sh

# Expose port 80 (nginx) and port 3000 (metrics)
EXPOSE 80 3000

CMD ["/app/start.sh"]
