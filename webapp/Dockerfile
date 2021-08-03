FROM ruby:3.0.2

WORKDIR /usr/src/app
COPY . ./

RUN gem install bundler --no-document && \
    bundle install

CMD ["bundle", "exec", "puma", "config.ru", "-C", "puma.rb", "-e", "production"]