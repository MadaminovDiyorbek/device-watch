FROM node:20-alpine

WORKDIR /app

ENV NODE_ENV=production

COPY package.json package-lock.json ./
RUN npm ci --omit=dev

COPY src ./src
COPY public ./public

RUN apk add --no-cache wget \
  && mkdir -p /app/data && chown -R node:node /app/data

USER node

EXPOSE 5050

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- http://127.0.0.1:5050/admin/ >/dev/null || exit 1

CMD ["node", "src/index.js"]
