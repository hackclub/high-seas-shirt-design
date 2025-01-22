FROM ruby:3.3.6-alpine

RUN apk add --update nodejs npm build-base chromium ttf-freefont udev bash

WORKDIR /code

COPY Gemfile Gemfile.lock package.json /code/
RUN bundle install; npm install

ENV WEB_CONCURRENCY=auto

COPY . /code

EXPOSE 42069

ENTRYPOINT ["/code/run.sh"]