# =========================
# Stage 1 — Builder
# =========================
FROM node:22-alpine AS builder

WORKDIR /app

COPY package.json pnpm-lock.yaml ./

RUN corepack enable \
 && pnpm install --frozen-lockfile

COPY . .

RUN pnpm build


# =========================
# Stage 2 — Runtime (distroless)
# =========================
FROM gcr.io/distroless/nodejs22-debian13

WORKDIR /app

ENV NODE_ENV=production

# Copy hanya hasil build (Nuxt output)
COPY --from=builder /app/.output ./

EXPOSE 3000

# ⚠️ distroless node sudah ENTRYPOINT ["node"]
CMD ["server/index.mjs"]
