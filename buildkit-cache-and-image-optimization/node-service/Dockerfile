# syntax=docker/dockerfile:1.12

FROM node:24-alpine AS dependencies

WORKDIR /app

COPY package.json package-lock.json ./

RUN --mount=type=cache,id=node-npm-cache,target=/root/.npm,sharing=locked \
    npm ci --omit=dev

FROM dependencies AS validation

COPY test.js ./

RUN npm test

FROM node:24-alpine AS runtime

ENV NODE_ENV=production
ENV PORT=3000

WORKDIR /app

COPY --from=dependencies /app/node_modules ./node_modules
COPY package.json package-lock.json server.js ./

RUN chown -R node:node /app

USER node

EXPOSE 3000

HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --quiet --spider http://127.0.0.1:3000/health || exit 1

CMD ["npm", "start"]
