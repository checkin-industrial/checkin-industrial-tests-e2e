# syntax=docker/dockerfile:1.6

# ── Stage 1: Build ───────────────────────────────────────────────────────────
FROM node:20-alpine AS build
WORKDIR /app

# 'painel' é um additional_context apontando para a pasta do projeto Painel.
COPY --from=painel package.json package-lock.json ./
# `npm install` (em vez de `ci`) tolera diferencas de plataforma no lock entre
# Windows e Linux (binarios nativos: @emnapi, rolldown). Mesma estrategia do
# CI do painel (.github/workflows/ci.yml).
RUN npm install --no-audit --no-fund

COPY --from=painel . .

# VITE_API_BASE vazio (default em apiClient.ts) faz todas as chamadas virarem
# relativas (/api/..., /uploads/...) e o nginx faz proxy_pass pra api:8080.
ENV VITE_API_BASE=""
RUN npm run build

# ── Stage 2: Serve ───────────────────────────────────────────────────────────
FROM nginx:1.27-alpine AS runtime

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
