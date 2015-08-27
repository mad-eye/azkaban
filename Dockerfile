FROM node:0.10.40
MAINTAINER Mike Risse

## make sure to git submodule --init --recursive the repor first

EXPOSE 4004
RUN apt-get update
ADD .madeye-common /app/.madeye-common
# RUN cd /app/.madeye-common && npm install --production
RUN cd /app && npm install .madeye-common
ADD package.json /app/package.json
RUN cd /app && npm install --production
ADD . /app


CMD /app/node_modules/.bin/coffee /app/app.coffee
