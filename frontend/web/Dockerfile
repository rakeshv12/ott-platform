# Use the trusted Node.js base image stored in private ECR.
ARG BASE_IMAGE_REPOSITORY

# Install frontend dependencies.
FROM ${BASE_IMAGE_REPOSITORY}:node-20-alpine AS deps

WORKDIR /app

COPY package.json ./
RUN npm install

# Build the Next.js application.
FROM ${BASE_IMAGE_REPOSITORY}:node-20-alpine AS builder

WORKDIR /app

COPY --from=deps /app/node_modules ./node_modules
COPY . .

RUN npm run build

# Run the production application using a non-root user.
FROM ${BASE_IMAGE_REPOSITORY}:node-20-alpine AS runner

WORKDIR /app

ENV NODE_ENV=production

RUN addgroup -S ottgroup && adduser -S ottuser -G ottgroup

COPY --from=builder /app/public ./public
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static

USER ottuser

EXPOSE 3000

CMD ["node", "server.js"]




# FROM node:20-alpine AS deps
# WORKDIR /app
# COPY package.json ./
# RUN npm install

# FROM node:20-alpine AS builder
# WORKDIR /app
# COPY --from=deps /app/node_modules ./node_modules
# COPY . .
# RUN npm run build

# FROM node:20-alpine AS runner
# WORKDIR /app
# ENV NODE_ENV=production

# RUN addgroup -S ottgroup && adduser -S ottuser -G ottgroup

# COPY --from=builder /app/public ./public
# COPY --from=builder /app/.next/standalone ./
# COPY --from=builder /app/.next/static ./.next/static

# USER ottuser
# EXPOSE 3000
# CMD ["node", "server.js"]
