
# Use the trusted Node.js base image stored in private ECR.
ARG BASE_IMAGE_REPOSITORY
FROM ${BASE_IMAGE_REPOSITORY}:node-20-alpine

WORKDIR /app

# Install production dependencies first for better Docker layer caching.
COPY package.json .
RUN npm install --production

# Copy application source.
COPY index.js .

EXPOSE 3003

CMD ["node", "index.js"]



# FROM node:20-alpine
# WORKDIR /app
# COPY package.json .
# RUN npm install --production
# COPY index.js .
# EXPOSE 3003
# CMD ["node", "index.js"]