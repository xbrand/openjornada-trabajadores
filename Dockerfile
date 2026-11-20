# Build stage
FROM node:22-alpine AS build

WORKDIR /app

# Install build dependencies for native modules
RUN apk add --no-cache python3 make g++

# Copy package files
COPY package*.json ./

# Remove package-lock to avoid conflicts with Alpine
RUN rm -f package-lock.json

# Install dependencies and force Rollup to install Alpine-compatible binaries
RUN npm install --force && \
    npm install @rollup/rollup-linux-x64-musl --force --save-optional

# Copy source code
COPY . .

# VITE_BASE_PATH MUST be set at build time (affects asset URLs)
# Use "/" for root path or "/trabajadores" for subpath
ARG VITE_BASE_PATH="/"

# VITE_BASE_PATH affects asset URLs and must be fixed at build time.
ENV VITE_BASE_PATH=$VITE_BASE_PATH

# Build the app
RUN npm run build

# Production stage
FROM nginx:alpine

# Apply every available security update to the base image.
#
# The "nginx:alpine" tag is a moving target, so an image built months ago
# freezes whatever the Alpine repositories offered at that moment. The
# published image had shipped brotli-libs 1.2.0-r1, libxslt 1.1.43-r3 and
# zlib 1.3.2-r1, which are affected by:
#   CVE-2026-111497  buffer overflow in the Brotli decoder (critical)
#   CVE-2026-125350  use-after-free in XML handling via libxslt (high)
#   CVE-2026-4738   out-of-bounds write in zlib (critical)
# Upgrading here guarantees the rebuilt image carries the patched packages
# regardless of when the base image was published.
RUN apk upgrade --no-cache

# Copy nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy built app from build stage
COPY --from=build /app/dist /usr/share/nginx/html

# Copy entrypoint script
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

# Expose port 80
EXPOSE 80

# Default values for runtime (can be overridden)
ENV VITE_API_URL=""
ENV VITE_API_USERNAME=""
ENV VITE_API_PASSWORD=""
ENV VITE_APP_NAME="OpenJornada"
ENV VITE_APP_LOGO="/logo.png"

# Generate runtime configuration at container startup.
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["nginx", "-g", "daemon off;"]
