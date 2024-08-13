FROM europe-west2-docker.pkg.dev/ons-ci/ons-ci/github-explorer-agent-parent-image-ghes:latest

WORKDIR /usr/src/app
COPY . ./

RUN groupadd --system --gid 1000 agent && \
    useradd agent --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    chown -R agent:agent .

USER 1000:1000

CMD ["bundle", "exec", "./agent.rb"]