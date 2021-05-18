FROM node:12.18.1
ENV NODE_ENV=production

WORKDIR /app

COPY package.json .

RUN npm install --production

COPY  server.js .

EXPOSE 30000
EXPOSE 30001
EXPOSE 40000
EXPOSE 40001

CMD [ "node", "server.js" ]
