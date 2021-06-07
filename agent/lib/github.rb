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
  PAUSE  = 0.5

  ALL_MEMBERS_CONTRIBUTIONS_QUERY = CLIENT.parse <<-'GRAPHQL'
    query ($slug: String!, $first: Int!, $after: String) {
      enterprise(slug: $slug) {
        members(first: $first, after: $after) {
          pageInfo {
            endCursor
            hasNextPage
          }
          nodes {
            ... on EnterpriseUserAccount {
              user {
                avatarUrl
                createdAt
                login
                name
                updatedAt
                contributionsCollection {
                  hasAnyContributions
                  restrictedContributionsCount
                  totalCommitContributions
                  totalIssueContributions
                  totalPullRequestContributions
                }
              }
            }
          }
        }
      }
    }
  GRAPHQL

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

  ALL_OUTSIDE_COLLABORATORS_CONTRIBUTIONS_QUERY = CLIENT.parse <<-'GRAPHQL'
    query ($slug: String!, $first: Int!, $after: String) {
      enterprise(slug: $slug) {
        ownerInfo {
          outsideCollaborators(first: $first, after: $after) {
            pageInfo {
              endCursor
              hasNextPage
            }
            nodes {
              avatarUrl
              createdAt
              login
              name
              updatedAt
              contributionsCollection {
                hasAnyContributions
                restrictedContributionsCount
                totalCommitContributions
                totalIssueContributions
                totalPullRequestContributions
              }
            }
          }
        }
      }
    }
  GRAPHQL

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

  ALL_TEAM_NAMES_QUERY = CLIENT.parse <<-'GRAPHQL'
    query($login: String!, $first: Int!, $after: String) {
      organization(login: $login) {
        teams(first: $first, after: $after) {
          pageInfo {
            endCursor
            hasNextPage
          }
          nodes {
            name
            privacy
            slug
          }
        }
      }
    }
  GRAPHQL

  TEAM_MEMBERS_QUERY = CLIENT.parse <<-'GRAPHQL'
    query ($login: String!, $slug: String!, $first: Int!, $after: String) {
      organization(login: $login) {
        team(slug: $slug) {
          members(first: $first, after: $after) {
            pageInfo {
              endCursor
              hasNextPage
            }
            nodes {
              login
            }
          }
        }
      }
    }
  GRAPHQL

  TWO_FACTOR_DISABLED_QUERY = CLIENT.parse <<-'GRAPHQL'
    query ($slug: String!, $first: Int!, $after: String) {
      enterprise(slug: $slug) {
        ownerInfo {
          affiliatedUsersWithTwoFactorDisabled(first: $first, after: $after) {
            pageInfo {
              endCursor
              hasNextPage
            }
            nodes {
              login
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

  def all_members_teams
    after = nil
    next_page = true
    all_members_teams = {}
    all_teams = []

    while next_page
      teams = CLIENT.query(ALL_TEAM_NAMES_QUERY, variables: { login: @organisation, first: 100, after: after },
                                                 context: { base_uri: @base_uri, token: @token })
      raise GitHubError, teams.errors unless teams.errors.empty?

      after = teams.data.organization.teams.page_info.end_cursor
      next_page = teams.data.organization.teams.page_info.has_next_page

      teams.data.organization.teams.nodes.each do |team|
        team_tuple = OpenStruct.new
        team_tuple.name    = team.name
        team_tuple.privacy = team.privacy
        team_tuple.slug    = team.slug
        all_teams << team_tuple

        team_logins = logins_for_team(team.slug)
        team_logins.each do |login|
          if all_members_teams.key?(login)
            all_members_teams[login] << team_tuple
          else
            all_members_teams[login] = [team_tuple]
          end
        end

        sleep PAUSE
      end
    end

    all_members_teams
  end

  def all_owners
    after = nil
    next_page = true
    all_owners = []

    while next_page
      members = CLIENT.query(ALL_MEMBERS_WITH_ROLES_QUERY, variables: { login: @organisation,
                                                                        first: 100, after: after },
                                                           context: { base_uri: @base_uri, token: @token })
      raise GitHubError, members.errors unless members.errors.empty?

      after = members.data.organization.members_with_role.page_info.end_cursor
      next_page = members.data.organization.members_with_role.page_info.has_next_page

      members.data.organization.members_with_role.edges.each do |member|
        user_tuple = OpenStruct.new
        user_tuple.login = member.node.login
        user_tuple.name  = member.node.name

        all_owners << user_tuple if member.role.eql?('ADMIN')
      end
    end

    all_owners.sort_by(&:login)
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

  def all_two_factor_disabled
    after = nil
    next_page = true
    all_two_factor_disabled = []

    while next_page
      logins = CLIENT.query(TWO_FACTOR_DISABLED_QUERY, variables: { slug: @enterprise, first: 100, after: after },
                                                       context: { base_uri: @base_uri, token: @token })
      raise GitHubError, logins.errors unless logins.errors.empty?

      after = logins.data.enterprise.owner_info.affiliated_users_with_two_factor_disabled.page_info.end_cursor
      next_page = logins.data.enterprise.owner_info.affiliated_users_with_two_factor_disabled.page_info.has_next_page

      logins.data.enterprise.owner_info.affiliated_users_with_two_factor_disabled.nodes.each do |user|
        all_two_factor_disabled << user.login
      end
    end

    all_two_factor_disabled.sort
  end

  def all_users_contributions
    after = nil
    next_page = true
    all_users_contributions = []

    while next_page
      members_contributions = CLIENT.query(ALL_MEMBERS_CONTRIBUTIONS_QUERY, variables: { slug: @enterprise,
                                                                                         first: 10, after: after },
                                                                            context: { base_uri: @base_uri,
                                                                                       token: @token })
      raise GitHubError, members_contributions.errors unless members_contributions.errors.empty?

      after = members_contributions.data.enterprise.members.page_info.end_cursor
      next_page = members_contributions.data.enterprise.members.page_info.has_next_page

      members_contributions.data.enterprise.members.nodes.each do |member|
        user_tuple = OpenStruct.new
        user_tuple.avatar_url                 = member.user.avatar_url
        user_tuple.created_at                 = member.user.created_at
        user_tuple.login                      = member.user.login
        user_tuple.name                       = member.user.name
        user_tuple.updated_at                 = member.user.updated_at
        user_tuple.has_contributions          = member.user.contributions_collection.has_any_contributions
        user_tuple.restricted_contributions   = member.user.contributions_collection.restricted_contributions_count
        user_tuple.commit_contributions       = member.user.contributions_collection.total_commit_contributions
        user_tuple.issue_contributions        = member.user.contributions_collection.total_issue_contributions
        user_tuple.pull_request_contributions = member.user.contributions_collection.total_pull_request_contributions
        user_tuple.member                     = true
        all_users_contributions << user_tuple
      end

      sleep PAUSE
    end

    after = nil
    next_page = true

    while next_page
      collaborators_contributions = CLIENT.query(ALL_OUTSIDE_COLLABORATORS_CONTRIBUTIONS_QUERY,
                                                 variables: { slug: @enterprise, first: 10, after: after },
                                                 context: { base_uri: @base_uri, token: @token })
      raise GitHubError, collaborators_contributions.errors unless collaborators_contributions.errors.empty?

      after = collaborators_contributions.data.enterprise.owner_info.outside_collaborators.page_info.end_cursor
      next_page = collaborators_contributions.data.enterprise.owner_info.outside_collaborators.page_info.has_next_page

      collaborators_contributions.data.enterprise.owner_info.outside_collaborators.nodes.each do |collaborator|
        user_tuple = OpenStruct.new
        user_tuple.avatar_url                 = collaborator.avatar_url
        user_tuple.created_at                 = collaborator.created_at
        user_tuple.login                      = collaborator.login
        user_tuple.name                       = collaborator.name
        user_tuple.updated_at                 = collaborator.updated_at
        user_tuple.has_contributions          = collaborator.contributions_collection.has_any_contributions
        user_tuple.restricted_contributions   = collaborator.contributions_collection.restricted_contributions_count
        user_tuple.commit_contributions       = collaborator.contributions_collection.total_commit_contributions
        user_tuple.issue_contributions        = collaborator.contributions_collection.total_issue_contributions
        user_tuple.pull_request_contributions = collaborator.contributions_collection.total_pull_request_contributions
        user_tuple.member                     = false
        all_users_contributions << user_tuple
      end

      sleep PAUSE
    end

    all_users_contributions.sort_by(&:login)
  end

  private

  def logins_for_team(slug)
    after = nil
    next_page = true
    logins_for_team = []

    while next_page
      team_members = CLIENT.query(TEAM_MEMBERS_QUERY, variables: { login: @organisation, slug: slug,
                                                                   first: 100, after: after },
                                                      context: { base_uri: @base_uri, token: @token })
      raise GitHubError, team_members.errors unless team_members.errors.empty?

      after = team_members.data.organization.team.members.page_info.end_cursor
      next_page = team_members.data.organization.team.members.page_info.has_next_page
      team_members.data.organization.team.members.nodes.each { |member| logins_for_team << member.login }
    end

    logins_for_team
  end
end
