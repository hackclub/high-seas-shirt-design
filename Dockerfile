FROM ruby:3.3.6

WORKDIR /code
COPY . /code
RUN bundle install

CMD ["bundle", "exec", "rackup", "--host", "0.0.0.0", "-p", "1337"]

EXPOSE 1337
