FROM europe-west2-docker.pkg.dev/ons-ci/ons-ci/github-explorer-webapp-parent-image:latest

WORKDIR /usr/src/app
COPY . ./

CMD ["bundle", "exec", "puma", "config.ru", "-C", "puma.rb", "-e", "production"]