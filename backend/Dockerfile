# Zoon API — production image (Fly.io / Oracle / any Docker host)
FROM node:20-bookworm-slim

WORKDIR /app

RUN apt-get update -y && apt-get install -y --no-install-recommends openssl ca-certificates \
  && rm -rf /var/lib/apt/lists/*

COPY package.json package-lock.json* ./
COPY prisma ./prisma

RUN npm install --omit=dev
RUN npx prisma generate

COPY src ./src

ENV NODE_ENV=production
ENV PORT=4000
EXPOSE 4000

# prisma generate already runs via postinstall; db push on boot if needed
CMD ["sh", "-c", "npx prisma db push && node src/app.js"]
