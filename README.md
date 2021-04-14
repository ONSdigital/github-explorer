# GitHub Explorer
This repository contains a [Ruby](https://ruby-lang.org/) [Sinatra](http://sinatrarb.com/) web application that consumes the [GitHub GraphQL API](https://docs.github.com/en/graphql) in order to provide insights into a GitHub organisation to make managing it easier.

## Installation
* Ensure that [Ruby](https://www.ruby-lang.org/en/downloads/) is installed
* Install [Bundler](https://bundler.io/) using `gem install bundler`
* Install the RubyGems this script depends on using `bundle install`

## Running
### Environment Variables
The environment variables below are required:

```
GITHUB_ENTERPRISE_NAME   # Name of the GitHub Enterprise
GITHUB_ORGANISATION_NAME # Name of the GitHub Organisation
GITHUB_TOKEN           # GitHub personal access token
```

### Token Scopes
The GitHub personal access token for using this application requires the following scopes:

- `admin:enterprise`
- `admin:org`
- `repo`
- `user`

## Copyright
Copyright (C) 2021 Crown Copyright (Office for National Statistics)
