FROM node:lts-alpine AS dependencies

WORKDIR /build

COPY package.json package-lock.json ./

RUN npm ci --omit=dev \
    && npm cache clean --force


FROM node:lts-alpine AS runtime

ENV NODE_ENV=production \
    PORT=3000

WORKDIR /app

RUN apk add --no-cache dumb-init \
    && addgroup -S appgroup \
    && adduser -S appuser -G appgroup

COPY --from=dependencies --chown=appuser:appgroup /build/node_modules ./node_modules
COPY --chown=appuser:appgroup server.js package.json ./

USER appuser

EXPOSE 3000

HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://127.0.0.1:3000/health',r=>process.exit(r.statusCode===200?0:1)).on('error',()=>process.exit(1))"

ENTRYPOINT ["dumb-init", "--"]

CMD ["node", "server.js"]
