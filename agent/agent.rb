#!/usr/bin/env ruby
# frozen_string_literal: true

require 'logger'
require 'ons-firestore'

require_relative 'lib/configuration'
require_relative 'lib/github'
require_relative 'lib/github_error'

# Class for executing named GitHub GraphQL API queries passed on the command-line.
class Agent
  CONFIG = Configuration.new(ENV)

  def initialize
    raise 'Missing GraphQL query command-line argument' if ARGV.empty?

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
      error_details = []
      error_details << "Type: #{e.type}" if e.type
      error_details << "Status Code: #{e.status_code}" if e.status_code
      error_details << "Message: #{e.message}" if e.message
      error_details << "Response Body: #{e.response_body}" if e.response_body

      if e.response_headers
        headers = e.response_headers.is_a?(Hash) ? e.response_headers.inspect : e.response_headers.to_s
        error_details << "Response Headers: #{headers}"
      end

      error_details << "Full Details: #{e.full_details.inspect}" if e.full_details.any?

      logger.error(%(A GitHub GraphQL API error occurred:\n#{error_details.join("\n")}\n#{e.backtrace.join("\n")}))
      exit(1)
    rescue StandardError => e
      error_message = e.message
      if e.respond_to?(:response)
        response = e.response
        error_message += "\nResponse Status: #{response.status}" if response.respond_to?(:status)
        error_message += "\nResponse Body: #{response.body}" if response.respond_to?(:body)
        if response.respond_to?(:headers)
          headers_str = response.headers.is_a?(Hash) ? response.headers.inspect : response.headers.to_s
          error_message += "\nResponse Headers: #{headers_str}"
        end
      end
      logger.error(%(An error occurred: #{error_message}\n#{e.backtrace.join("\n")}))
      exit(1)
    end
  end
end

Agent.new
