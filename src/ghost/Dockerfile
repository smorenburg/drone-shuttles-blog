FROM ghost:4.33.1-alpine as base

FROM base as builder

WORKDIR ${GHOST_INSTALL}

# Copy the package files.
COPY package*.json ./

# Install the packages.
RUN npm install --only=production

FROM base

WORKDIR ${GHOST_INSTALL}

# Copy the packages from builder.
COPY --from=builder ${GHOST_INSTALL}/node_modules ./node_modules

# Remove the symlink and copy the config files.
RUN rm -f config.development.json
COPY config*.json ./

# Copy the adapters
COPY adapters ./content/adapters

# Copy the themes
COPY themes ./content/themes

# checkov:skip=CKV_DOCKER_2: Health check is not necessary.
# checkov:skip=CKV_DOCKER_3: User is defined in base image.