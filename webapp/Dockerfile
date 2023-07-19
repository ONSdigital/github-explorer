FROM europe-west2-docker.pkg.dev/ons-ci/ons-ci/github-explorer-webapp-parent-image-ghes:latest

ARG BRANCH="main"
ARG COMMIT=""
ARG REPO=""
LABEL branch=${BRANCH}
LABEL commit=${COMMIT}
LABEL repo=${REPO}

WORKDIR /usr/src/app
COPY . ./

ENV COMMIT_SHA=${COMMIT}
ENV COMMIT_BRANCH=${BRANCH}
ENV REPO_NAME=${REPO}

CMD ["bundle", "exec", "puma", "config.ru", "-C", "puma.rb", "-e", "production"]