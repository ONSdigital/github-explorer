# GitHub Explorer
This repository contains a web application that provide insights into a GitHub organisation to make managing it easier.

## Organisation
This repository contains the following sub-directories:

* [agent](https://github.com/ONSdigital/github-explorer/tree/master/agent) - [Go](https://golang.org/) application that runs as a Kubernetes [CronJob](https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/). It makes various heavyweight requests to the [GitHub GraphQL API](https://docs.github.com/en/graphql) in order to retrieve information displayed by the web application. A [Cloud Firestore](https://cloud.google.com/firestore/) database is used as persistent storage

* [webapp](https://github.com/ONSdigital/github-explorer/tree/master/webapp) - [Ruby](https://ruby-lang.org/) [Sinatra](http://sinatrarb.com/) application that displays the information held in Firestore and also makes lightweight requests to the GitHub GraphQL API

## Building the Agent
For the agent application, use `make` to compile binaries for macOS and Linux.

## Installing the Web Application
* Ensure that [Ruby](https://www.ruby-lang.org/en/downloads/) is installed
* Install [Bundler](https://bundler.io/) using `gem install bundler`
* Install the RubyGems this script depends on using `bundle install`

## Environment Variables
The environment variables below are required:

| Component | Variable                   | Purpose                                                                     |
|-----------|----------------------------|-----------------------------------------------------------------------------|
| agent     | `FIRESTORE_PROJECT`        | Name of the GCP project containing the Firestore database.                  |
|           | `GITHUB_API_BASE_URI`      | URI of GitHub's GraphQL API host.                                           |
|           | `GITHUB_ENTERPRISE_NAME`   | Name of the GitHub Enterprise.                                              |
|           | `GITHUB_ORGANISATION_NAME` | Name of the GitHub Organisation.                                            |
|           | `GITHUB_TOKEN`             | GitHub personal access token. See below for details of the required scopes. |
| webapp    | `FIRESTORE_PROJECT`        | Name of the GCP project containing the Firestore database.                  |
|           | `GITHUB_API_BASE_URI`      | URI of GitHub's GraphQL API host.                                           |
|           | `GITHUB_ENTERPRISE_NAME`   | Name of the GitHub Enterprise.                                              |
|           | `GITHUB_ORGANISATION_NAME` | Name of the GitHub Organisation.                                            |
|           | `GITHUB_TOKEN`             | GitHub personal access token. See below for details of the required scopes. |

## Running the Web Application
Run the application locally using the [Puma web server](https://puma.io/) with the command:

```
bundle exec puma config.ru -C puma.rb
```

The web application will then be available at http://localhost:3000/

## GitHub Personal Access Token Scopes
The GitHub personal access token for using this application requires the following scopes:

- `admin:enterprise`
- `admin:org`
- `repo`
- `user`

### To Do
- Extract expensive queries into a separate out-of-band process run on a schedule
- Correctly handle nested paging through results for `ALL_TEAMS_ALL_MEMBERS_QUERY` GraphQL query
- Refactor `lib/github.rb` God class
- Extract common view code into partials
- Make tables sortable by different columns
- Make the table filter fields operate against the full list rather than just the current page

## Copyright
Copyright (C) 2021 Crown Copyright (Office for National Statistics)
