# frozen_string_literal: true

require 'ostruct'
require 'graphql/client'
require 'graphql/client/http'

require_relative 'context_transport'
require_relative 'github_error'

# Class that encapsulates access to the GitHub GraphQL API.
class GitHub
  SCHEMA = GraphQL::Client.load_schema(File.join(__dir__, 'graphql', 'schema.json'))
  CLIENT = GraphQL::Client.new(schema: SCHEMA, execute: ContextTransport.new)

  ALL_REPOSITORIES_QUERY = CLIENT.parse <<-'GRAPHQL'
    query ($login: String!, $first: Int!, $after: String) {
      organization(login: $login) {
        repositories(first: $first, after: $after, orderBy: {field: NAME, direction: ASC}) {
          pageInfo {
            endCursor
            hasNextPage
          }
          nodes {
            createdAt
            description
            isArchived
            isPrivate
            name
            updatedAt
            branchProtectionRules(first: 1) {
              totalCount
            }
            collaborators(first: 1) {
              totalCount
            }
            primaryLanguage {
              name
            }
            vulnerabilityAlerts(first: 1) {
              totalCount
            }
          }
        }
      }
    }
  GRAPHQL

  def initialize(enterprise, organisation, base_uri, token)
    @enterprise   = enterprise
    @organisation = organisation
    @base_uri     = URI.parse(base_uri)
    @token        = token
  end

  def all_repositories
    after = nil
    next_page = true
    all_repositories = []

    while next_page
      repositories = CLIENT.query(ALL_REPOSITORIES_QUERY, variables: { login: @organisation, first: 100, after: after },
                                                          context: { base_uri: @base_uri, token: @token })
      raise GitHubError, repositories.errors unless repositories.errors.empty?

      after = repositories.data.organization.repositories.page_info.end_cursor
      next_page = repositories.data.organization.repositories.page_info.has_next_page

      repositories.data.organization.repositories.nodes.each { |repository| all_repositories << repository }
    end

    all_repositories
  end
end
