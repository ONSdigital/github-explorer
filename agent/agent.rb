#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'logger'

require_relative 'lib/configuration'
require_relative 'lib/firestore'
require_relative 'lib/github'
require_relative 'lib/github_error'

# Class that
class Agent
  CONFIG = Configuration.new(ENV)
  GITHUB = GitHub.new(CONFIG.github_enterprise, CONFIG.github_organisation,
                      CONFIG.github_api_base_uri, CONFIG.github_token)

  def initialize
    raise 'Missing GraphQL query command-line argument' if ARGV.length.zero?

    logger = Logger.new($stdout)

    begin
      query = ARGV[0]
      query_result = GITHUB.send(query)
      firestore = Firestore.new(CONFIG.firestore_project, logger)
      firestore.save_document(query, query_result)
    rescue GitHubError => e
      logger.error("A GitHub GraphQL API error occurred: #{e.message}")
      exit(1)
    rescue StandardError => e
      logger.error("An error occurred: #{e.message}")
      exit(1)
    end
  end
end

Agent.new
