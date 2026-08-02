FROM node:lts-alpine AS builder

WORKDIR /app

COPY package*.json ./
COPY tsconfig.json ./

RUN npm install

COPY . .

RUN npm run build

FROM node:lts-alpine

WORKDIR /app

COPY package*.json ./

RUN npm install --omit=dev \
 && npm cache clean --force

COPY --from=builder /app/dist ./dist

RUN addgroup -S nodejs \
 && adduser -S nodejs -G nodejs

USER nodejs

EXPOSE 3000

HEALTHCHECK CMD wget -qO- http://localhost:3000 || exit 1

CMD ["npm","start"]
