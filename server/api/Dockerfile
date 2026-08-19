# Build context is the `server/` directory, not `server/api/`, because the API
# runs the SQL migrations at boot and they live in `server/db/migrations`.
#
# No native modules here on purpose — password hashing uses node:crypto scrypt
# rather than argon2/bcrypt, so this image needs no toolchain and builds fast.
FROM node:22-alpine

WORKDIR /app

COPY api/package.json ./
RUN npm install --no-audit --no-fund

COPY api/tsconfig.json ./
COPY api/src ./src
RUN npm run build && npm prune --omit=dev

COPY db/migrations ./db/migrations

ENV NODE_ENV=production
EXPOSE 3000
CMD ["node", "dist/index.js"]
