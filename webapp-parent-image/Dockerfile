FROM ruby:3.1.2

WORKDIR /usr/src/app
COPY . ./

RUN gem install bundler --no-document && \
    bundle install