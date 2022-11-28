#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'logger'
require 'ons-firestore'

require_relative 'lib/configuration'
require_relative 'lib/github'
require_relative 'lib/github_error'

# Class for executing named GitHub GraphQL API queries passed on the command-line.
class Agent
  CONFIG = Configuration.new(ENV)

  def initialize
    raise 'Missing GraphQL query command-line argument' if ARGV.length.zero?

    logger = Logger.new($stdout)

    begin
      query = ARGV[0]

      CONFIG.github_organisations.split(',').each do |organisation|
        github = GitHub.new(CONFIG.github_enterprise, organisation,
                            CONFIG.github_api_base_uri, CONFIG.github_token)

        query_result = github.send(query)
        firestore = Firestore.new(CONFIG.firestore_project)
        firestore.save_document("github-explorer-#{organisation}", query, query_result)
      end
    rescue GitHubError => e
      logger.error(%(A GitHub GraphQL API error occurred: #{e.message}\n#{e.backtrace.join("\n")}))
      exit(1)
    rescue StandardError => e
      logger.error(%(An error occurred: #{e.message}\n#{e.backtrace.join("\n")}))
      exit(1)
    end
  end
end

Agent.new
