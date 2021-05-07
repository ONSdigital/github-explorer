FROM ruby:3.0.0

WORKDIR /usr/src/app
COPY . ./

RUN gem install bundler --no-document && bundle install

CMD ["bundle", "exec", "./agent.rb"]