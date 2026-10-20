# syntax=docker/dockerfile:1
FROM node:24-bookworm-slim@sha256:a5f4366e834695d5f363b920c104953a535d3a9864d1bdf74566a0ebe01daee5 AS dependencies
WORKDIR /app/server
COPY server/package.json server/package-lock.json ./
RUN --mount=type=secret,id=proxy_ca \
    if [ -f /run/secrets/proxy_ca ]; then export NODE_EXTRA_CA_CERTS=/run/secrets/proxy_ca; fi; \
    npm ci --omit=dev --ignore-scripts --no-audit --no-fund --strict-ssl=true

FROM node:24-bookworm-slim@sha256:a5f4366e834695d5f363b920c104953a535d3a9864d1bdf74566a0ebe01daee5
ENV NODE_ENV=production APP_ENV=production HOST=0.0.0.0 PORT=8080 DATA_DIR=/app/data WEB_ROOT=/app/web ALLOW_REGISTRATION=false
WORKDIR /app/server
COPY --from=dependencies /app/server/node_modules ./node_modules
COPY server/package.json ./
COPY server/src ./src
COPY server/migrations ./migrations
COPY docs/legal/chart-of-accounts-2026.json /app/docs/legal/chart-of-accounts-2026.json
COPY build/web /app/web
COPY deploy/container-entrypoint.mjs /app/container-entrypoint.mjs
RUN chmod -R a+rX /app && mkdir /app/data && chown node:node /app/data
USER node
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 CMD ["node","-e","fetch('http://127.0.0.1:8080/health').then(r=>{if(!r.ok)process.exit(1)}).catch(()=>process.exit(1))"]
ENTRYPOINT ["node","/app/container-entrypoint.mjs"]
CMD ["src/main.js"]
