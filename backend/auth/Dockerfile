FROM node:20-alpine

WORKDIR /app

# Install dependencies first (layer cache)
COPY package.json .
RUN npm install --production

# Copy source
COPY index.js .

# Non-root user for security
RUN addgroup -S ottgroup && adduser -S ottuser -G ottgroup
USER ottuser

EXPOSE 3001

CMD ["node", "index.js"]
