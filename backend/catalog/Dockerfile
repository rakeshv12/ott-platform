FROM node:20-alpine
WORKDIR /app
COPY package.json .
RUN npm install --production
COPY index.js .
RUN addgroup -S ottgroup && adduser -S ottuser -G ottgroup
USER ottuser
EXPOSE 3002
CMD ["node", "index.js"]