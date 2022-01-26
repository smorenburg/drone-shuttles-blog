FROM ghost:4.33.1-alpine

# Install the GCS adapter.
RUN mkdir -p /tmp/gcs ${GHOST_CONTENT}/adapters/storage/gcs && \
    wget -O - "$(npm view @danmasta/ghost-gcs-adapter dist.tarball)" | tar xz -C /tmp/gcs && \
    npm install --prefix /tmp/gcs/package --silent --only=production --no-optional --no-progress && \
    mv /tmp/gcs/package/* ${GHOST_CONTENT}/adapters/storage/gcs

# Remove the symlink and copy the config files.
RUN rm -f /var/lib/ghost/config.development.json
COPY config.development.json /var/lib/ghost/config.development.json
COPY config.production.json /var/lib/ghost/config.production.json

# Copy the themes
COPY themes /var/lib/ghost/content/themes

#HEALTHCHECK CMD curl --fail http://localhost:2368 || exit 1
#
#USER node
