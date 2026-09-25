# Use the trusted Node.js base image stored in private ECR.
ARG BASE_IMAGE_REPOSITORY
FROM ${BASE_IMAGE_REPOSITORY}:node-20-alpine

WORKDIR /app

# Install production dependencies first for better Docker layer caching.
COPY package.json .
RUN npm install --production

# Copy application source.
COPY index.js .

# Run the application as a non-root user for better container security.
RUN addgroup -S ottgroup && adduser -S ottuser -G ottgroup
USER ottuser

EXPOSE 3002

CMD ["node", "index.js"]



# FROM node:20-alpine
# WORKDIR /app
# COPY package.json .
# RUN npm install --production
# COPY index.js .
# RUN addgroup -S ottgroup && adduser -S ottuser -G ottgroup
# USER ottuser
# EXPOSE 3002
# CMD ["node", "index.js"]