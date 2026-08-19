# Baileys pulls `libsignal` straight from git and builds a native module, so the
# image needs git and a toolchain at install time. They are pruned afterwards.
FROM node:22-alpine

RUN apk add --no-cache git python3 make g++

WORKDIR /app

COPY package.json ./
RUN npm install --no-audit --no-fund

COPY tsconfig.json ./
COPY src ./src
RUN npm run build && npm prune --omit=dev

ENV NODE_ENV=production
EXPOSE 3100
CMD ["node", "dist/index.js"]
