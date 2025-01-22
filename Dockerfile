FROM ruby:3.3.6-alpine

RUN apk add --update nodejs npm build-base

WORKDIR /code

COPY Gemfile Gemfile.lock /code/
RUN bundle install

COPY . /code

EXPOSE 42069

CMD ["bundle", "exec", "rackup", "--host", "0.0.0.0", "-p", "42069"]