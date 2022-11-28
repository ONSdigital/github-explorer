# GitHub Explorer
This repository contains a [Ruby](https://ruby-lang.org/) web application that provide insights into a GitHub organisation to make managing it easier.

## Organisation
This repository contains the following sub-directories:

* [agent](https://github.com/ONSdigital/github-explorer/tree/main/agent) - Ruby command-line application that runs as a Kubernetes [CronJob](https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/). It makes various heavyweight requests to the [GitHub GraphQL API](https://docs.github.com/en/graphql) in order to retrieve information displayed by the web application. A [Cloud Firestore](https://cloud.google.com/firestore/) database is used as persistent storage

* [agent-parent-image](https://github.com/ONSdigital/github-explorer/tree/main/agent-parent-image) - Docker parent image containing Ruby and the dependencies required by the agent application. Used to speed up the Docker build

* [webapp](https://github.com/ONSdigital/github-explorer/tree/main/webapp) - Ruby [Sinatra](http://sinatrarb.com/) application that displays the information held in Firestore and also makes lightweight requests to the GitHub GraphQL API

* [webapp-parent-image](https://github.com/ONSdigital/github-explorer/tree/main/webapp-parent-image) - Docker parent image containing Ruby and the dependencies required by the web application. Used to speed up the Docker build

## Building the Applications
Dockerfiles are included for building both the agent and web application.

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
|           | `GITHUB_ORGANISATIONS`     | Comma-separated list of GitHub organisation names.                          |
|           | `GITHUB_TOKEN`             | GitHub personal access token. See below for details of the required scopes. |

## GitHub Personal Access Token Scopes
The GitHub personal access token for using this application requires the following scopes:

- `admin:enterprise`
- `admin:org`
- `read:user`
- `repo`
- `user:email`

## Agent Cron Jobs
The agent command line application supports the cron jobs detailed below. The query results are written to Firestore using the query name as the document name.

| Name                      | Purpose
|---------------------------|-------------------------------------------------------------------------------|
| `all_inactive_users`      | Retrieves a list of users within no contributions within the past six months. |
| `all_members_teams`       | Retrieves a list of all organisation members and the teams they belong to.    |
| `all_owners`              | Retrieves a list of all organisation owners.                                  |
| `all_repositories`        | Retrieves a list of all repositories                                          |
| `all_two_factor_disabled` | Retrieves a list of all users without two-factor authentication enabled.      |
| `all_users_contributions` | Retrieves a list of all users within statistics on their contributions.       |
| `teamless_members`        | Retrieves a list of all users who don't belong to any team.                   |

## Copyright
Copyright (C) 2021 Crown Copyright (Office for National Statistics)
