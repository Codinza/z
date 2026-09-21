# Build from repo root (Railway monorepo) — only the API
FROM node:20-bookworm-slim

WORKDIR /app

RUN apt-get update -y \
  && apt-get install -y --no-install-recommends openssl ca-certificates \
  && rm -rf /var/lib/apt/lists/*

COPY backend/package.json backend/package-lock.json* ./
COPY backend/prisma ./prisma

RUN npm install --omit=dev \
  && npx prisma generate

COPY backend/src ./src

ENV NODE_ENV=production
ENV PORT=4000
EXPOSE 4000

CMD ["sh", "-c", "npx prisma db push && node src/app.js"]
