FROM europe-west2-docker.pkg.dev/ons-ci/ons-ci/github-explorer-agent-parent-image:latest

WORKDIR /usr/src/app
COPY . ./

CMD ["bundle", "exec", "./agent.rb"]