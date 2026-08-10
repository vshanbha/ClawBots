# Start: ClawBots (our base)
FROM ghcr.io/zeroclaw-labs/zeroclaw:debian

# Install dependencies
USER root
RUN apt-get update \
    && apt-get install -y --no-install-recommends libatomic1 sudo \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Set HOME to match runtime so nvm installs to the right place
ENV HOME=/zeroclaw-data
ENV NVM_DIR="/zeroclaw-data/.nvm"

# Install nvm + node + agent-browser
ARG NVM_VERSION=v0.40.6
ARG NODE_VERSION=26
RUN mkdir -p /zeroclaw-data \
    && curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh | bash

RUN . "${NVM_DIR}/nvm.sh" \
    && nvm install ${NODE_VERSION} \
    && nvm alias default ${NODE_VERSION} \
    && node -v \
    && npm -v \
    && npm install -g corepack \
    && corepack enable pnpm \
    && pnpm -v \
    && npm install -g agent-browser

# Create stable "v26" symlink so PATH doesn't break on minor version bump
RUN ACTUAL=$(ls -d "${NVM_DIR}/versions/node/v${NODE_VERSION}."* | head -1) \
    && ln -s "$ACTUAL" "${NVM_DIR}/versions/node/v${NODE_VERSION}"

RUN . "${NVM_DIR}/nvm.sh" \
    && agent-browser install --with-deps

# Add node bin to PATH for runtime
ENV PATH="${NVM_DIR}/versions/node/v${NODE_VERSION}/bin:${PATH}"

# Remove sudo (only needed during build)
RUN rm /usr/bin/sudo
