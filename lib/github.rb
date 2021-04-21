# frozen_string_literal: true

require 'ostruct'
require 'graphql/client'
require 'graphql/client/http'

require_relative 'context_transport'

# Class that encapsulates access to the GitHub GraphQL API.
class GitHub
  attr_reader :members_teams, :owners

  SCHEMA = GraphQL::Client.load_schema(File.join(__dir__, 'graphql', 'schema.json'))
  CLIENT = GraphQL::Client.new(schema: SCHEMA, execute: ContextTransport.new)

  ALL_MEMBERS_WITH_ROLES_QUERY = CLIENT.parse <<-'GRAPHQL'
    query($login: String!, $first: Int!, $after: String) {
      organization(login: $login) {
        membersWithRole(first: $first, after: $after) {
          pageInfo {
            endCursor
            hasNextPage
          }
          edges {
            node {
              login
              name
            }
            role
          }
        }
      }
    }
  GRAPHQL

  ALL_MEMBERS_QUERY = CLIENT.parse <<-'GRAPHQL'
    query($slug: String!, $first: Int, $after: String) {
      enterprise(slug: $slug) {
        members(first: $first, after: $after) {
          totalCount
          pageInfo {
            startCursor
            endCursor
            hasNextPage
            hasPreviousPage
          }
          nodes {
            ... on EnterpriseUserAccount {
              avatarUrl(size: 20)
              createdAt
              login
              name
              user {
                email
                updatedAt
              }
            }
          }
        }
      }
    }
  GRAPHQL

  ALL_TEAMS_ALL_MEMBERS_QUERY = CLIENT.parse <<-'GRAPHQL'
    query($login: String!) {
      organization(login: $login) {
        teams(first: 100) {
          nodes {
            name
            privacy
            members(first: 100) {
              nodes {
                login
              }
            }
          }
        }
      }
    }
  GRAPHQL

  ALL_TEAMS_QUERY = CLIENT.parse <<-'GRAPHQL'
    query($login: String!, $first: Int, $last: Int, $before: String, $after: String) {
      organization(login: $login) {
        teams(first: $first, last: $last, before: $before, after: $after) {
          totalCount
          pageInfo {
            startCursor
            endCursor
            hasNextPage
            hasPreviousPage
          }
          nodes {
            createdAt
            description
            name
            privacy
            updatedAt
            parentTeam {
              name
            }
            childTeams(first: 100) {
              totalCount
              nodes {
                createdAt
                description
                name
                privacy
                updatedAt
                members(first: 1) {
                  totalCount
                }
              }
            }
            members(first: 1) {
              totalCount
            }
          }
        }
      }
    }
  GRAPHQL

  MEMBER_QUERY = CLIENT.parse <<-'GRAPHQL'
    query($slug: String!, $login: String!) {
      enterprise(slug: $slug) {
        members(first: 1, query: $login) {
          nodes {
            ... on EnterpriseUserAccount {
              avatarUrl(size: 250)
              createdAt
              login
              name
              user {
                bio
                company
                email
                location
                updatedAt
                twitterUsername
                websiteUrl
                contributionsCollection {
                  hasAnyContributions
                }
                followers(first: 1) {
                  totalCount
                }
                following(first: 1) {
                  totalCount
                }
                organizations(first: 10) {
                  nodes {
                    avatarUrl
                    name
                  }
                }
                starredRepositories(first: 1) {
                  totalCount
                }
                topRepositories(first: 10, orderBy: { field: NAME, direction: ASC }) {
                  nodes {
                    name
                    isPrivate
                  }
                }
              }
            }
          }
        }
      }
    }
  GRAPHQL

  SUMMARY_QUERY = CLIENT.parse <<-'GRAPHQL'
    query($login: String!, $slug: String!) {
      enterprise(slug: $slug) {
        avatarUrl
        createdAt
        description
        location
        name
        url
        websiteUrl
        billingInfo {
          totalAvailableLicenses
          totalLicenses
        }
        members(first: 1) {
          totalCount
        }
        ownerInfo {
          admins(first: 1) {
            nodes {
              login
              name
            }
          }
          outsideCollaborators(first: 1) {
            totalCount
          }
        }
      }
      organization(login: $login) {
        avatarUrl
        createdAt
        description
        location
        name
        updatedAt
        url
        websiteUrl
        repositories(first: 1) {
          totalCount
        }
        publicRepositories: repositories(first: 1, privacy: PUBLIC) {
          totalCount
        }
        privateRepositories: repositories(first: 1, privacy: PRIVATE) {
          totalCount
        }
        teams(first: 1) {
          totalCount
        }
        secretTeams: teams(first: 1, privacy: SECRET) {
          totalCount
        }
        visibleTeams: teams(first: 1, privacy: VISIBLE) {
          totalCount
        }
      }
    }
  GRAPHQL

  def initialize(base_uri, token)
    @base_uri = URI.parse(base_uri)
    @token    = token
    @members_teams = {}
    @owners        = Set[]
  end

  def all_members(enterprise)
    after = nil
    next_page = true
    all_members = []

    while next_page
      members = CLIENT.query(ALL_MEMBERS_QUERY, variables: { slug: enterprise, first: 100, after: after },
                                                context: { base_uri: @base_uri, token: @token })
      after = members.data.enterprise.members.page_info.end_cursor
      next_page = members.data.enterprise.members.page_info.has_next_page
      members.data.enterprise.members.nodes.each { |member| all_members << member }
    end

    all_members
  end

  def all_teams(organisation, first = nil, last = nil, before = nil, after = nil)
    first_count = first.to_i if first
    last_count  = last.to_i if last
    CLIENT.query(ALL_TEAMS_QUERY, variables: { login: organisation, first: first_count, last: last_count,
                                               before: before, after: after },
                                  context: { base_uri: @base_uri, token: @token })
  end

  def owner?(login)
    @owners.each { |owner| return true if owner.login.eql?(login) }
    false
  end

  def member(enterprise, login)
    CLIENT.query(MEMBER_QUERY, variables: { slug: enterprise, login: login },
                               context: { base_uri: @base_uri, token: @token })
  end

  def perform_member_role_lookup(organisation)
    after = nil
    next_page = true

    while next_page
      members = CLIENT.query(ALL_MEMBERS_WITH_ROLES_QUERY, variables: { login: organisation, first: 100, after: after },
                                                           context: { base_uri: @base_uri, token: @token })
      after = members.data.organization.members_with_role.page_info.end_cursor
      next_page = members.data.organization.members_with_role.page_info.has_next_page

      members.data.organization.members_with_role.edges.each do |member|
        user_tuple = OpenStruct.new
        user_tuple.login = member.node.login
        user_tuple.name  = member.node.name

        @owners << user_tuple if member.role.eql?('ADMIN')
      end
    end
  end

  def perform_team_membership_lookup(organisation)
    teams = CLIENT.query(ALL_TEAMS_ALL_MEMBERS_QUERY, variables: { login: organisation },
                                                      context: { base_uri: @base_uri, token: @token })

    teams.data.organization.teams.nodes.each do |team|
      team_tuple = OpenStruct.new
      team_tuple.name    = team.name
      team_tuple.privacy = team.privacy

      team.members.nodes.each do |member|
        if @members_teams.key?(member.login)
          @members_teams[member.login] << team_tuple
        else
          @members_teams[member.login] = Set[team_tuple]
        end
      end
    end
  end

  def summary(enterprise, organisation)
    CLIENT.query(SUMMARY_QUERY, variables: { login: organisation, slug: enterprise },
                                context: { base_uri: @base_uri, token: @token })
  end
end
