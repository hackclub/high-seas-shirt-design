FROM ruby:3.3.6-alpine

WORKDIR /code
COPY . /code

RUN apk add --update nodejs npm build-base

RUN bundle install

EXPOSE 42069

CMD ["bundle", "exec", "rackup", "--host", "0.0.0.0", "-p", "42069"]