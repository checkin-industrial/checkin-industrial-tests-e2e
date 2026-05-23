# syntax=docker/dockerfile:1.6

# ── Stage 1: Build ───────────────────────────────────────────────────────────
FROM node:20-alpine AS build
WORKDIR /app

# 'painel' é um additional_context apontando para a pasta do projeto Painel.
COPY --from=painel package.json package-lock.json ./
RUN npm ci

COPY --from=painel . .

# Neutraliza a URL hardcoded em src/apiClient.ts:7. Com API_BASE = "" todas as
# chamadas viram relativas (/api/..., /uploads/...) e o nginx faz proxy_pass.
RUN sed -i 's|"https://appturismoindustrial-production.up.railway.app"|""|' src/apiClient.ts

RUN npm run build

# ── Stage 2: Serve ───────────────────────────────────────────────────────────
FROM nginx:1.27-alpine AS runtime

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
