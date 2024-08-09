FROM europe-west2-docker.pkg.dev/ons-ci/ons-ci/github-explorer-webapp-parent-image:latest

ARG BRANCH="main"
ARG COMMIT=""
ARG REPO=""
LABEL branch=${BRANCH}
LABEL commit=${COMMIT}
LABEL repo=${REPO}

WORKDIR /usr/src/app
COPY . ./

RUN groupadd --system --gid 1000 webapp && \
    useradd webapp --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    chown -R webapp:webapp .

USER 1000:1000

ENV COMMIT_SHA=${COMMIT}
ENV COMMIT_BRANCH=${BRANCH}
ENV REPO_NAME=${REPO}

CMD ["bundle", "exec", "puma", "config.ru", "-C", "puma.rb", "-e", "production"]