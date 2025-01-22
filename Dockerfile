FROM ruby:3.3.6-alpine

RUN apk add --update nodejs npm build-base chromium ttf-freefont udev

WORKDIR /code

COPY Gemfile Gemfile.lock package.json /code/
RUN bundle install; npm install

ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser
ENV WEB_CONCURRENCY=auto

COPY . /code

EXPOSE 42069

CMD ["bundle", "exec", "rackup", "--host", "0.0.0.0", "-p", "42069"]