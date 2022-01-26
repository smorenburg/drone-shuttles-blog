FROM ghost:4.32.3-alpine

# Install the GCS adapter.
RUN mkdir -p content/adapters/storage/gcs && \
    npm install ghost-v3-google-cloud-storage && \
    mv node_modules/ghost-v3-google-cloud-storage/* content/adapters/storage/gcs/

# Copy the themes
COPY themes /var/lib/ghost/content/themes

#HEALTHCHECK CMD curl --fail http://localhost:2368 || exit 1
#
#USER node
