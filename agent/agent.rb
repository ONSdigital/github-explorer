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
    Logger.new($stdout).error(%(A GitHub GraphQL API error occurred: #{e.type} #{e.message}\n#{e.backtrace.join("\n")}))
    exit(1)
  rescue StandardError => e
    Logger.new($stdout).error(%(An error occurred: #{e.message}\n#{e.backtrace.join("\n")}))
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
end

Agent.new
