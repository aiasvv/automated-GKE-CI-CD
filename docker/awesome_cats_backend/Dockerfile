FROM --platform=linux/amd64 node:14-slim
WORKDIR /app

COPY package*.json ./
RUN npm install

COPY . .
ENV NODE_ENV=production

# EXPOSE 3001
CMD ["node", "server.js"]