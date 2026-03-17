FROM ruby:3.4.9

WORKDIR /usr/src/app
COPY . ./

RUN gem install bundler --no-document && \
    bundle install