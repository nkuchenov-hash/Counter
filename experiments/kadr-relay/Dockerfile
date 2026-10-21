FROM node:20-alpine
WORKDIR /app
RUN npm install --no-audit --no-fund --omit=dev ws@8.18.3
COPY relay.js /app/relay.js
ENV NODE_ENV=production
EXPOSE 8443
CMD ["node", "/app/relay.js"]
