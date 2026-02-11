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
  CHUNK_SIZE = 500

  def initialize
    raise 'Missing GraphQL query command-line argument' if ARGV.empty?

    execute_query(ARGV[0])
  rescue GitHubError => e
    log_github_error(e)
    exit(1)
  rescue StandardError => e
    log_standard_error(e)
    exit(1)
  end

  private

  def execute_query(query)
    CONFIG.github_organisations.split(',').each do |organisation|
      github = GitHub.new(CONFIG.github_enterprise, organisation,
                          CONFIG.github_api_base_uri, CONFIG.github_token)

      query_result = github.send(query)
      firestore = Firestore.new(CONFIG.firestore_project)
      collection = "github-explorer-#{organisation}"

      if query_result.is_a?(Array) && query_result.size > CHUNK_SIZE
        save_chunked_document(firestore, collection, query, query_result)
      else
        firestore.save_document(collection, query, query_result)
      end
    end
  end

  def save_chunked_document(firestore, collection, query, query_result)
    chunks = query_result.each_slice(CHUNK_SIZE).to_a

    chunks.each_with_index do |chunk, index|
      firestore.save_document(collection, "#{query}_chunk_#{index}", chunk)
    end

    firestore.save_document(collection, query, { 'chunk_count' => chunks.size })
  end

  def log_github_error(err)
    logger = Logger.new($stdout)
    error_details = []
    error_details << "Type: #{err.type}" if err.type
    error_details << "Status Code: #{err.status_code}" if err.status_code
    error_details << "Message: #{err.message}" if err.message
    error_details << "Response Body: #{err.response_body}" if err.response_body

    if err.response_headers
      headers = err.response_headers.is_a?(Hash) ? err.response_headers.inspect : err.response_headers.to_s
      error_details << "Response Headers: #{headers}"
    end

    error_details << "Full Details: #{err.full_details.inspect}" if err.full_details.any?

    logger.error(%(A GitHub GraphQL API error occurred:\n#{error_details.join("\n")}\n#{err.backtrace.join("\n")}))
  end

  def log_standard_error(err)
    logger = Logger.new($stdout)
    error_message = err.message

    if err.respond_to?(:response)
      response = err.response
      error_message += "\nResponse Status: #{response.status}" if response.respond_to?(:status)
      error_message += "\nResponse Body: #{response.body}" if response.respond_to?(:body)
      if response.respond_to?(:headers)
        headers_str = response.headers.is_a?(Hash) ? response.headers.inspect : response.headers.to_s
        error_message += "\nResponse Headers: #{headers_str}"
      end
    end

    logger.error(%(An error occurred: #{error_message}\n#{err.backtrace.join("\n")}))
  end
end

Agent.new
