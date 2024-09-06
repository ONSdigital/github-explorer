# frozen_string_literal: true

require 'graphlient'

require_relative '../github_error'
require_relative 'user'
require_relative 'team'

# Class that encapsulates access to the GitHub GraphQL API.
# rubocop:disable Metrics/ClassLength
class GraphQLClient
  ALL_OUTSIDE_COLLABORATORS_QUERY = <<-GRAPHQL
    query ($slug: String!, $first: Int!, $after: String) {
      enterprise(slug: $slug) {
        ownerInfo {
          outsideCollaborators(first: $first, after: $after) {
            pageInfo {
              endCursor
              hasNextPage
            }
            edges {
              node {
                avatarUrl
                createdAt
                email
                login
                name
                updatedAt
              }
              repositories(first: 1) {
                totalCount
              }
            }
          }
        }
      }
    }
  GRAPHQL

  ALL_TEAMS_QUERY = <<-GRAPHQL
    query ($login: String!, $first: Int!, $after: String) {
      organization(login: $login) {
        teams(first: $first, after: $after, rootTeamsOnly: true, orderBy: {field: NAME, direction: ASC}) {
          pageInfo {
            endCursor
            hasNextPage
          }
          nodes {
            avatarUrl
            createdAt
            description
            name
            privacy
            slug
            updatedAt
            members(first: 1, membership: IMMEDIATE) {
              totalCount
            }
            childTeams(first: 5, orderBy: {field: NAME, direction: ASC}) {
              nodes {
                avatarUrl
                createdAt
                description
                name
                privacy
                slug
                updatedAt
                members(first: 1, membership: IMMEDIATE) {
                  totalCount
                }
                childTeams(first: 5, orderBy: {field: NAME, direction: ASC}) {
                  totalCount
                  nodes {
                    avatarUrl
                    createdAt
                    description
                    name
                    privacy
                    slug
                    updatedAt
                    members(first: 1, membership: IMMEDIATE) {
                      totalCount
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  GRAPHQL

  MEMBER_QUERY = <<-GRAPHQL
    query($slug: String!, $login: String!, $user_login: String!) {
      enterprise(slug: $slug) {
        members(first: 1, query: $user_login) {
          nodes {
            ... on EnterpriseUserAccount {
              user {
                avatarUrl
                bio
                company
                createdAt
                databaseId
                email
                location
                login
                name
                organizationVerifiedDomainEmails(login: $login)
                twitterUsername
                updatedAt
                url
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
                    isPrivate
                    name
                  }
                }
              }
            }
          }
        }
      }
      organization(login: $login) {
        name
        samlIdentityProvider {
          externalIdentities(first: 1, login: $user_login) {
            nodes {
              samlIdentity {
                nameId
              }
            }
          }
        }
      }
    }
  GRAPHQL

  ORGANISATION_QUERY = <<-GRAPHQL
    query($login: String!, $slug: String!) {
      rateLimit {
        limit
        remaining
        resetAt
      }
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
          admins(first: 10) {
            nodes {
              login
              name
            }
          }
          outsideCollaborators(first: 1) {
            totalCount
          }
          pendingMemberInvitations(first: 1) {
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
        samlIdentityProvider {
          ssoUrl
          externalIdentities(first: 1) {
            totalCount
          }
        }
      }
    }
  GRAPHQL

  OUTSIDE_COLLABORATOR_QUERY = <<-GRAPHQL
    query ($slug: String!, $login: String!) {
      enterprise(slug: $slug) {
        ownerInfo {
          outsideCollaborators(first: 1, query: $login) {
            edges {
              node {
                avatarUrl
                bio
                company
                createdAt
                databaseId
                email
                location
                login
                name
                twitterUsername
                updatedAt
                url
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
                topRepositories(first: 10, orderBy: {field: NAME, direction: ASC}) {
                  nodes {
                    isPrivate
                    name
                  }
                }
              }
              repositories(first: 50) {
                nodes {
                  isPrivate
                  name
                }
              }
            }
          }
        }
      }
    }
  GRAPHQL

  RATE_LIMIT_QUERY = <<-GRAPHQL
    {
      rateLimit {
        limit
        remaining
        resetAt
      }
    }
  GRAPHQL

  REPOSITORY_QUERY = <<-GRAPHQL
    query ($login: String!, $name: String!) {
      organization(login: $login) {
        repository(name: $name) {
          createdAt
          description
          forkCount
          isArchived
          isEmpty
          isPrivate
          isTemplate
          name
          pushedAt
          stargazerCount
          updatedAt
          url
          branchProtectionRules(first: 10) {
            nodes {
              allowsDeletions
              allowsForcePushes
              creator {
                login
              }
              dismissesStaleReviews
              isAdminEnforced
              pattern
              requiredApprovingReviewCount
              requiresCodeOwnerReviews
              requiresCommitSignatures
              requiresLinearHistory
              requiresStatusChecks
              requiresStrictStatusChecks
              restrictsPushes
              restrictsReviewDismissals
            }
          }
          defaultBranchRef {
            name
          }
          languages(first: 10) {
            edges {
              size
              node {
                color
                name
              }
            }
          }
          licenseInfo {
            name
          }
          repositoryTopics(first: 20) {
            nodes {
              topic {
                name
              }
            }
          }
          vulnerabilityAlerts(first: 1) {
            totalCount
          }
          watchers(first: 1) {
            totalCount
          }
        }
      }
    }
  GRAPHQL

  REPOSITORY_ACCESS_QUERY = <<-GRAPHQL
    query ($login: String!, $name: String!, $first: Int!, $after: String) {
      organization(login: $login) {
        name
        repository(name: $name) {
          collaborators(first: $first, after: $after) {
            pageInfo {
              endCursor
              hasNextPage
            }
            edges {
              node {
                login
                name
                organizations(first: 5) {
                  nodes {
                    name
                  }
                }
              }
              permissionSources {
                permission
                source {
                  ... on Organization {
                    organisationName: name
                  }
                  ... on Repository {
                    repositoryName: name
                  }
                  ... on Team {
                    slug
                    teamName: name
                    parentTeam {
                      name
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  GRAPHQL

  SECRET_TEAMS_QUERY = <<-GRAPHQL
    query ($login: String!, $first: Int!, $after: String) {
      organization(login: $login) {
        teams(first: $first, after: $after, privacy: SECRET, rootTeamsOnly: true, orderBy: {field: NAME, direction: ASC}) {
          pageInfo {
            endCursor
            hasNextPage
          }
          nodes {
            avatarUrl
            createdAt
            description
            name
            privacy
            slug
            updatedAt
            members(first: 1, membership: IMMEDIATE) {
              totalCount
            }
            childTeams(first: 5, orderBy: {field: NAME, direction: ASC}) {
              nodes {
                avatarUrl
                createdAt
                description
                name
                privacy
                slug
                updatedAt
                members(first: 1, membership: IMMEDIATE) {
                  totalCount
                }
                childTeams(first: 5, orderBy: {field: NAME, direction: ASC}) {
                  totalCount
                  nodes {
                    avatarUrl
                    createdAt
                    description
                    name
                    privacy
                    slug
                    updatedAt
                    members(first: 1, membership: IMMEDIATE) {
                      totalCount
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  GRAPHQL

  TEAM_QUERY = <<-GRAPHQL
    query ($login: String!, $first: Int!, $after: String, $slug: String!) {
      organization(login: $login) {
        team(slug: $slug) {
          avatarUrl
          createdAt
          description
          name
          privacy
          updatedAt
          url
          members(first: $first, after: $after, membership: IMMEDIATE) {
            pageInfo {
              endCursor
              hasNextPage
            }
            edges {
              role
              node {
                email
                login
                name
              }
            }
          }
          ancestors(first: 10) {
            nodes {
              name
              privacy
              slug
              ancestors(first: 10) {
                nodes {
                  name
                  privacy
                  slug
                  ancestors(first: 10) {
                    nodes {
                      name
                      privacy
                      slug
                    }
                  }
                }
              }
            }
          }
          childTeams(first: 10, orderBy: {field: NAME, direction: ASC}) {
            nodes {
              name
              slug
              childTeams(first: 10, orderBy: {field: NAME, direction: ASC}) {
                nodes {
                  name
                  slug
                  childTeams(first: 10, orderBy: {field: NAME, direction: ASC}) {
                    nodes {
                      name
                      slug
                      childTeams(first: 10, orderBy: {field: NAME, direction: ASC}) {
                        nodes {
                          name
                          slug
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  GRAPHQL

  TWO_FACTOR_DISABLED_USERS_QUERY = <<-GRAPHQL
    query ($login: String!, $slug: String!, $first: Int!, $after: String) {
      enterprise(slug: $slug) {
        ownerInfo {
          affiliatedUsersWithTwoFactorDisabled(first: $first, after: $after) {
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
              organizations(first: 5) {
                nodes {
                  name
                }
              }
            }
          }
        }
      }
      organization(login: $login) {
        name
      }
    }
  GRAPHQL

  VISIBLE_TEAMS_QUERY = <<-GRAPHQL
    query ($login: String!, $first: Int!, $after: String) {
      organization(login: $login) {
        teams(first: $first, after: $after, privacy: VISIBLE, rootTeamsOnly: true, orderBy: {field: NAME, direction: ASC}) {
          pageInfo {
            endCursor
            hasNextPage
          }
          nodes {
            avatarUrl
            createdAt
            description
            name
            privacy
            slug
            updatedAt
            members(first: 1, membership: IMMEDIATE) {
              totalCount
            }
            childTeams(first: 5, orderBy: {field: NAME, direction: ASC}) {
              nodes {
                avatarUrl
                createdAt
                description
                name
                privacy
                slug
                updatedAt
                members(first: 1, membership: IMMEDIATE) {
                  totalCount
                }
                childTeams(first: 5, orderBy: {field: NAME, direction: ASC}) {
                  totalCount
                  nodes {
                    avatarUrl
                    createdAt
                    description
                    name
                    privacy
                    slug
                    updatedAt
                    members(first: 1, membership: IMMEDIATE) {
                      totalCount
                    }
                  }
                }
              }
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
                                           schema_path: 'schema.json')
  end

  # rubocop:disable Metrics/AbcSize
  def all_outside_collaborators
    after = nil
    next_page = true
    all_outside_collaborators = []

    while next_page
      collaborators = @client.query(ALL_OUTSIDE_COLLABORATORS_QUERY, { slug: @enterprise, first: 100, after: })
      raise GitHubError, collaborators.errors unless collaborators.errors.empty?

      after = collaborators.data.enterprise.owner_info.outside_collaborators.page_info.end_cursor
      next_page = collaborators.data.enterprise.owner_info.outside_collaborators.page_info.has_next_page

      collaborators.data.enterprise.owner_info.outside_collaborators.edges.each do |collaborator|
        all_outside_collaborators << collaborator
      end
    end

    all_outside_collaborators
  end
  # rubocop:enable Metrics/AbcSize

  # rubocop:disable Metrics/AbcSize
  def all_teams
    after = nil
    next_page = true
    all_teams = []

    while next_page
      teams = @client.query(ALL_TEAMS_QUERY, { login: @organisation, first: 100, after: })
      raise GitHubError, teams.errors unless teams.errors.empty?

      after = teams.data.organization.teams.page_info.end_cursor
      next_page = teams.data.organization.teams.page_info.has_next_page
      teams.data.organization.teams.nodes.each { |team| all_teams << team }
    end

    all_teams
  end
  # rubocop:enable Metrics/AbcSize

  def member(user_login)
    member = @client.query(MEMBER_QUERY, { slug: @enterprise, login: @organisation, user_login: })
    raise GitHubError, member.errors unless member.errors.empty?

    member
  end

  def organisation
    organisation = @client.query(ORGANISATION_QUERY, { login: @organisation, slug: @enterprise })
    raise GitHubError, organisation.errors unless organisation.errors.empty?

    organisation
  end

  def outside_collaborator(login)
    outside_collaborator = @client.query(OUTSIDE_COLLABORATOR_QUERY, { slug: @enterprise, login: })
    raise GitHubError, outside_collaborator.errors unless outside_collaborator.errors.empty?

    outside_collaborator
  end

  def rate_limit
    @client.query(RATE_LIMIT_QUERY, context: { base_uri: @base_uri, token: @token })
  end

  def repository(repository)
    begin
      repository = @client.query(REPOSITORY_QUERY, { login: @organisation, name: repository })
      raise GitHubError, repository.errors unless repository.errors.empty?
    rescue Graphlient::Errors::ExecutionError # Occurs when the repository doesn't exist.
      repository = nil
    end

    repository
  end

  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
  def repository_access(repository)
    after = nil
    next_page = true
    repository_access = Set[]

    while next_page
      access = @client.query(REPOSITORY_ACCESS_QUERY, { login: @organisation, name: repository, first: 100, after: })
      raise GitHubError, access.errors unless access.errors.empty?

      break if access.data.organization.repository.nil?

      after = access.data.organization.repository.collaborators.page_info.end_cursor
      next_page = access.data.organization.repository.collaborators.page_info.has_next_page

      access.data.organization.repository.collaborators.edges.each do |collaborator_edge|
        next if collaborator_edge.node.nil?

        user = User.new(collaborator_edge.node.login, collaborator_edge.node.name, member: false)

        collaborator_edge.node.organizations.nodes.each do |org|
          if org.name.eql?(access.data.organization.name)
            user.member = true
            break
          end
        end

        collaborator_edge.permission_sources.each do |permission_source|
          case permission_source.source.__typename
          when 'Organization'
            user.organisation_permission = permission_source.permission
          when 'Repository'
            user.repository_name       = permission_source.source.repository_name
            user.repository_permission = permission_source.permission
          when 'Team'
            user.team_parent     = permission_source.source.parent_team
            user.team_permission = permission_source.permission
            user.team_name = permission_source.source.team_name
            user.team_slug = permission_source.source.slug
          end
        end

        repository_access << user
      end
    end

    repository_access.sort_by(&:login)
  end
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity

  # rubocop:disable Metrics/AbcSize
  def secret_teams
    after = nil
    next_page = true
    secret_teams = []

    while next_page
      teams = @client.query(SECRET_TEAMS_QUERY, { login: @organisation, first: 100, after: })
      raise GitHubError, teams.errors unless teams.errors.empty?

      after = teams.data.organization.teams.page_info.end_cursor
      next_page = teams.data.organization.teams.page_info.has_next_page
      teams.data.organization.teams.nodes.each { |team| secret_teams << team }
    end

    secret_teams
  end
  # rubocop:enable Metrics/AbcSize

  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  def team(slug)
    after     = nil
    next_page = true
    team      = Team.new

    while next_page
      t = @client.query(TEAM_QUERY, { login: @organisation, slug:, first: 100, after: })
      raise GitHubError, t.errors unless t.errors.empty?

      after = t.data.organization.team.members.page_info.end_cursor
      next_page = t.data.organization.team.members.page_info.has_next_page

      team.avatar_url  = t.data.organization.team.avatar_url
      team.created_at  = t.data.organization.team.created_at
      team.description = t.data.organization.team.description
      team.name        = t.data.organization.team.name
      team.privacy     = t.data.organization.team.privacy
      team.updated_at  = t.data.organization.team.updated_at
      team.url         = t.data.organization.team.url

      unless t.data.organization.team.ancestors.nodes.nil? # rubocop:disable Style/IfUnlessModifier
        team.ancestors = t.data.organization.team.ancestors.nodes
      end

      unless t.data.organization.team.child_teams.nodes.nil?
        team.child_teams = t.data.organization.team.child_teams.nodes
      end

      t.data.organization.team.members.edges.each do |member|
        team.members << User.new(member.node.login, member.node.name, role: member.role)
      end
    end

    team.members.sort_by!(&:login)
    team
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  def two_factor_disabled_users
    after = nil
    next_page = true
    two_factor_disabled_users = []

    while next_page
      users = @client.query(TWO_FACTOR_DISABLED_USERS_QUERY,
                            { login: @organisation, slug: @enterprise, first: 100, after: })

      raise GitHubError, users.errors unless users.errors.empty?

      after = users.data.enterprise.owner_info.affiliated_users_with_two_factor_disabled.page_info.end_cursor
      next_page = users.data.enterprise.owner_info.affiliated_users_with_two_factor_disabled.page_info.has_next_page

      users.data.enterprise.owner_info.affiliated_users_with_two_factor_disabled.nodes.each do |u|
        next if u.nil?

        user = User.new(u.login, u.name)
        user.avatar_url = u.avatar_url
        user.created_at = u.created_at
        user.email      = u.email
        user.updated_at = u.updated_at

        u.organizations.nodes.each do |org|
          if org.name.eql?(users.data.organization.name)
            user.member = true
            break
          end
        end

        two_factor_disabled_users << user
      end
    end

    two_factor_disabled_users
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

  # rubocop:disable Metrics/AbcSize
  def visible_teams
    after = nil
    next_page = true
    visible_teams = []

    while next_page
      teams = @client.query(VISIBLE_TEAMS_QUERY, { login: @organisation, first: 100, after: })
      raise GitHubError, teams.errors unless teams.errors.empty?

      after = teams.data.organization.teams.page_info.end_cursor
      next_page = teams.data.organization.teams.page_info.has_next_page
      teams.data.organization.teams.nodes.each { |team| visible_teams << team }
    end

    visible_teams
  end
  # rubocop:enable Metrics/AbcSize
end
# rubocop:enable Metrics/ClassLength
