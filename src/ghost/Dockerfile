FROM ghost:4.33.1-alpine

# Copy the adapters.
COPY adapters /var/lib/ghost/content/adapters

# Remove the symlink and copy the config files.
RUN rm -f /var/lib/ghost/config.development.json
COPY config.development.json /var/lib/ghost/config.development.json
COPY config.production.json /var/lib/ghost/config.production.json

# Copy the themes
COPY themes /content/themes
