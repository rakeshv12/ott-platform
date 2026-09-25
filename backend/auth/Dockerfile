# Use the trusted Node.js base image stored in private ECR.
# The repository is supplied at build time through BASE_IMAGE_REPOSITORY.
ARG BASE_IMAGE_REPOSITORY
FROM ${BASE_IMAGE_REPOSITORY}:node-20-alpine

WORKDIR /app

# Install dependencies first so Docker can reuse this layer
# when application source code changes.
COPY package.json .
RUN npm install --production

# Copy application source.
COPY index.js .

# Run the application as a non-root user for better container security.
RUN addgroup -S ottgroup && adduser -S ottuser -G ottgroup
USER ottuser

EXPOSE 3001

CMD ["node", "index.js"]



# FROM node:20-alpine
# WORKDIR /app
# # Install dependencies first (layer cache)
# COPY package.json .
# RUN npm install --production
# # Copy source
# COPY index.js .
# # Non-root user for security
# RUN addgroup -S ottgroup && adduser -S ottuser -G ottgroup
# USER ottuser
# EXPOSE 3001
# CMD ["node", "index.js"]
