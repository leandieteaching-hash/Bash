FROM node:22-alpine AS dependencies
WORKDIR /workspace
COPY package.json package-lock.json ./
COPY apps/web/package.json apps/web/package.json
RUN npm ci

FROM node:22-alpine AS builder
WORKDIR /workspace
COPY --from=dependencies /workspace/node_modules ./node_modules
COPY . .
RUN npm run build

FROM node:22-alpine AS runtime
ENV NODE_ENV=production
WORKDIR /workspace
RUN addgroup --system --gid 1001 studio && adduser --system --uid 1001 studio
COPY --from=builder --chown=studio:studio /workspace/apps/web/.next/standalone ./
COPY --from=builder --chown=studio:studio /workspace/apps/web/.next/static ./apps/web/.next/static
COPY --from=builder --chown=studio:studio /workspace/apps/web/public ./apps/web/public
USER studio
EXPOSE 3000
ENV PORT=3000
CMD ["node", "apps/web/server.js"]
