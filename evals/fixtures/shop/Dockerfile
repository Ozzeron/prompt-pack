# Planted: D5 (floating tag, single stage, runs as root, dev deps in the image)
FROM node:latest

WORKDIR /app
COPY . .
RUN npm install

EXPOSE 3000
CMD npm start
