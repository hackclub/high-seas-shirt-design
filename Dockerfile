FROM ruby:3.3.6-alpine

WORKDIR /code
COPY . /code
RUN apk add imagemagick imagemagick-pdf build-base
RUN bundle install
CMD ["bundle", "exec", "rackup", "--host", "0.0.0.0", "-p", "1337"]

EXPOSE 1337
