# frozen_string_literal: true

require 'date'
require 'graphlient'

require_relative 'github_error'
require_relative 'team'
require_relative 'user'

# Class that encapsulates access to the GitHub GraphQL API.
class GitHub
  INACTIVE_MONTHS = 6
  PAUSE           = 0.5

  ALL_INACTIVE_MEMBERS_QUERY = <<-GRAPHQL
    query ($login: String!, $slug: String!, $first: Int!, $from: DateTime!, $after: String) {
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
                email
                login
                name
                organizationVerifiedDomainEmails(login: $login)
                updatedAt
                contributionsCollection(from: $from) {
                  hasAnyContributions
                }
              }
            }
          }
        }
      }
    }
  GRAPHQL

  ALL_INACTIVE_OUTSIDE_COLLABORATORS_QUERY = <<-GRAPHQL
    query ($slug: String!, $first: Int!, $from: DateTime!, $after: String) {
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
              email
              login
              name
              updatedAt
              contributionsCollection(from: $from) {
                hasAnyContributions
              }
            }
          }
        }
      }
    }
  GRAPHQL

  ALL_MEMBERS_CONTRIBUTIONS_QUERY = <<-GRAPHQL
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

  ALL_MEMBERS_WITH_ROLES_QUERY = <<-GRAPHQL
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

  ALL_MEMBERS_QUERY = <<-GRAPHQL
    query($login: String!, $slug: String!, $first: Int!, $after: String) {
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
                email
                login
                name
                organizationVerifiedDomainEmails(login: $login)
                updatedAt
                organizations(first: 10) {
                  nodes {
                    resourcePath
                  }
                }
              }
            }
          }
        }
      }
    }
  GRAPHQL

  ALL_OUTSIDE_COLLABORATORS_CONTRIBUTIONS_QUERY = <<-GRAPHQL
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

  ALL_REPOSITORIES_QUERY = <<-GRAPHQL
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
            isTemplate
            name
            pushedAt
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

  ALL_TEAM_NAMES_QUERY = <<-GRAPHQL
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

  TEAM_MEMBERS_QUERY = <<-GRAPHQL
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

  TWO_FACTOR_DISABLED_QUERY = <<-GRAPHQL
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
    @client       = Graphlient::Client.new("#{base_uri}/graphql",
                                           headers: { 'Authorization' => "Bearer #{token}" },
                                           http_options: { read_timeout: 20 },
                                           schema_path: File.join(__dir__, 'graphql', 'schema.json'))
  end

  def all_inactive_users
    after = nil
    next_page = true
    from = DateTime.now.prev_month(INACTIVE_MONTHS).iso8601
    all_inactive_users = []

    while next_page
      inactive_members = @client.query(ALL_INACTIVE_MEMBERS_QUERY,
                                       { login: @organisation, slug: @enterprise, from:, first: 10, after: })
      raise GitHubError, inactive_members.errors unless inactive_members.errors.empty?

      after = inactive_members.data.enterprise.members.page_info.end_cursor
      next_page = inactive_members.data.enterprise.members.page_info.has_next_page

      inactive_members.data.enterprise.members.nodes.each do |member|
        next if member.user.nil?

        unless member.user.contributions_collection.has_any_contributions
          user = User.new(member.user.login, member.user.name)
          user.avatar_url    = member.user.avatar_url
          user.created_at    = member.user.created_at
          user.domain_emails = member.user.organization_verified_domain_emails
          user.email         = member.user.email
          user.updated_at    = member.user.updated_at
          user.member        = true
          all_inactive_users << user
        end
      end

      sleep PAUSE
    end

    after = nil
    next_page = true

    while next_page
      inactive_collaborators = @client.query(ALL_INACTIVE_OUTSIDE_COLLABORATORS_QUERY,
                                             { slug: @enterprise, from:, first: 10, after: })
      raise GitHubError, inactive_collaborators.errors unless inactive_collaborators.errors.empty?

      after = inactive_collaborators.data.enterprise.owner_info.outside_collaborators.page_info.end_cursor
      next_page = inactive_collaborators.data.enterprise.owner_info.outside_collaborators.page_info.has_next_page

      inactive_collaborators.data.enterprise.owner_info.outside_collaborators.nodes.each do |collaborator|
        next if collaborator.nil?

        unless collaborator.contributions_collection.has_any_contributions
          user = User.new(collaborator.login, collaborator.name)
          user.avatar_url = collaborator.avatar_url
          user.created_at = collaborator.created_at
          user.email      = collaborator.email
          user.updated_at = collaborator.updated_at
          user.member     = false
          all_inactive_users << user
        end
      end

      sleep PAUSE
    end

    all_inactive_users.sort_by(&:login)
  end

  def all_members
    after = nil
    next_page = true
    all_members = []

    while next_page
      members = @client.query(ALL_MEMBERS_QUERY, { login: @organisation, slug: @enterprise, first: 100, after: })
      raise GitHubError, members.errors unless members.errors.empty?

      after = members.data.enterprise.members.page_info.end_cursor
      next_page = members.data.enterprise.members.page_info.has_next_page

      members.data.enterprise.members.nodes.each do |member|
        next if member.user.nil?

        user = User.new(member.user.login, member.user.name)
        user.avatar_url    = member.user.avatar_url
        user.created_at    = member.user.created_at
        user.domain_emails = member.user.organization_verified_domain_emails
        user.email         = member.user.email
        user.updated_at    = member.user.updated_at

        organisations = []
        member.user.organizations.nodes.each { |node| organisations << node.resource_path[1..].downcase }
        user.organisations = organisations

        all_members << user
      end
    end

    all_members
  end

  def all_members_teams
    after = nil
    next_page = true
    all_members_teams = {}
    all_teams = []

    while next_page
      teams = @client.query(ALL_TEAM_NAMES_QUERY, { login: @organisation, first: 100, after: })
      raise GitHubError, teams.errors unless teams.errors.empty?

      after = teams.data.organization.teams.page_info.end_cursor
      next_page = teams.data.organization.teams.page_info.has_next_page

      teams.data.organization.teams.nodes.each do |t|
        team = Team.new(t.name, t.privacy, t.slug)
        all_teams << team

        team_logins = logins_for_team(team.slug)
        team_logins.each do |login|
          if all_members_teams.key?(login)
            all_members_teams[login] << team
          else
            all_members_teams[login] = [team]
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
      members = @client.query(ALL_MEMBERS_WITH_ROLES_QUERY, { login: @organisation, first: 100, after: })
      raise GitHubError, members.errors unless members.errors.empty?

      after = members.data.organization.members_with_role.page_info.end_cursor
      next_page = members.data.organization.members_with_role.page_info.has_next_page

      members.data.organization.members_with_role.edges.each do |member|
        next if member.node.nil?

        user = User.new(member.node.login, member.node.name)
        all_owners << user if member.role.eql?('ADMIN')
      end
    end

    all_owners.sort_by(&:login)
  end

  def all_repositories
    after = nil
    next_page = true
    all_repositories = []

    while next_page
      repositories = @client.query(ALL_REPOSITORIES_QUERY, { login: @organisation, first: 100, after: })
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
      logins = @client.query(TWO_FACTOR_DISABLED_QUERY, { slug: @enterprise, first: 100, after: })
      raise GitHubError, logins.errors unless logins.errors.empty?

      after = logins.data.enterprise.owner_info.affiliated_users_with_two_factor_disabled.page_info.end_cursor
      next_page = logins.data.enterprise.owner_info.affiliated_users_with_two_factor_disabled.page_info.has_next_page

      logins.data.enterprise.owner_info.affiliated_users_with_two_factor_disabled.nodes.each do |user|
        next if user.nil?

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
      members_contributions = @client.query(ALL_MEMBERS_CONTRIBUTIONS_QUERY, { slug: @enterprise, first: 10, after: })
      raise GitHubError, members_contributions.errors unless members_contributions.errors.empty?

      after = members_contributions.data.enterprise.members.page_info.end_cursor
      next_page = members_contributions.data.enterprise.members.page_info.has_next_page

      members_contributions.data.enterprise.members.nodes.each do |member|
        next if member.user.nil?

        user = User.new(member.user.login, member.user.name)
        user.avatar_url                 = member.user.avatar_url
        user.created_at                 = member.user.created_at
        user.updated_at                 = member.user.updated_at
        user.has_contributions          = member.user.contributions_collection.has_any_contributions
        user.restricted_contributions   = member.user.contributions_collection.restricted_contributions_count
        user.commit_contributions       = member.user.contributions_collection.total_commit_contributions
        user.issue_contributions        = member.user.contributions_collection.total_issue_contributions
        user.pull_request_contributions = member.user.contributions_collection.total_pull_request_contributions
        user.member                     = true
        all_users_contributions << user
      end

      sleep PAUSE
    end

    after = nil
    next_page = true

    while next_page
      collaborators_contributions = @client.query(ALL_OUTSIDE_COLLABORATORS_CONTRIBUTIONS_QUERY,
                                                  { slug: @enterprise, first: 10, after: })
      raise GitHubError, collaborators_contributions.errors unless collaborators_contributions.errors.empty?

      after = collaborators_contributions.data.enterprise.owner_info.outside_collaborators.page_info.end_cursor
      next_page = collaborators_contributions.data.enterprise.owner_info.outside_collaborators.page_info.has_next_page

      collaborators_contributions.data.enterprise.owner_info.outside_collaborators.nodes.each do |collaborator|
        next if collaborator.nil?

        user = User.new(collaborator.login, collaborator.name)
        user.avatar_url                 = collaborator.avatar_url
        user.created_at                 = collaborator.created_at
        user.updated_at                 = collaborator.updated_at
        user.has_contributions          = collaborator.contributions_collection.has_any_contributions
        user.restricted_contributions   = collaborator.contributions_collection.restricted_contributions_count
        user.commit_contributions       = collaborator.contributions_collection.total_commit_contributions
        user.issue_contributions        = collaborator.contributions_collection.total_issue_contributions
        user.pull_request_contributions = collaborator.contributions_collection.total_pull_request_contributions
        user.member                     = false
        all_users_contributions << user
      end

      sleep PAUSE
    end

    all_users_contributions.sort_by(&:login)
  end

  def teamless_members
    teamless_members = []
    members_with_a_team = all_members_teams

    all_members.each do |member|
      next if member.nil?

      user = User.new(member.login, member.name)
      user.avatar_url    = member.avatar_url
      user.created_at    = member.created_at
      user.domain_emails = member.domain_emails
      user.email         = member.email
      user.updated_at    = member.updated_at
      teamless_members << user unless members_with_a_team.key?(member.login)
    end

    teamless_members
  end

  private

  def logins_for_team(slug)
    after = nil
    next_page = true
    logins_for_team = []

    while next_page
      team_members = @client.query(TEAM_MEMBERS_QUERY, { login: @organisation, slug:, first: 100, after: })
      raise GitHubError, team_members.errors unless team_members.errors.empty?

      after = team_members.data.organization.team.members.page_info.end_cursor
      next_page = team_members.data.organization.team.members.page_info.has_next_page
      team_members.data.organization.team.members.nodes.each do |member|
        next if member.nil?

        logins_for_team << member.login
      end
    end

    logins_for_team
  end
end
