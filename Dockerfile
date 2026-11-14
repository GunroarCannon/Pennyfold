# Pennyfold shared-world server (presence, chat, raids). No npm packages.
FROM node:20-alpine
WORKDIR /app
COPY server/world_server.mjs ./world_server.mjs
ENV PORT=8000 SEED=2026
EXPOSE 8000
CMD ["node", "world_server.mjs"]
