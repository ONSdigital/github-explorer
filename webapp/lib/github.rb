# frozen_string_literal: true

require 'ostruct'
require 'graphql/client'
require 'graphql/client/http'

require_relative 'context_transport'
require_relative 'github_error'

# Class that encapsulates access to the GitHub GraphQL API.
class GitHub
  attr_reader :two_factor_disabled

  SCHEMA = GraphQL::Client.load_schema(File.join(__dir__, 'graphql', 'schema.json'))
  CLIENT = GraphQL::Client.new(schema: SCHEMA, execute: ContextTransport.new)

  ALL_MEMBERS_QUERY = CLIENT.parse <<-'GRAPHQL'
    query($slug: String!, $first: Int!, $after: String) {
      enterprise(slug: $slug) {
        members(first: $first, after: $after) {
          pageInfo {
            endCursor
            hasNextPage
          }
          nodes {
            ... on EnterpriseUserAccount {
              avatarUrl
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

  ALL_OUTSIDE_COLLABORATORS_QUERY = CLIENT.parse <<-'GRAPHQL'
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

  ALL_TEAMS_QUERY = CLIENT.parse <<-'GRAPHQL'
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

  MEMBER_QUERY = CLIENT.parse <<-'GRAPHQL'
    query($slug: String!, $login: String!, $user_login: String!) {
      enterprise(slug: $slug) {
        members(first: 1, query: $user_login) {
          nodes {
            ... on EnterpriseUserAccount {
              avatarUrl
              createdAt
              login
              name
              user {
                bio
                company
                email
                location
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
      }
    }
  GRAPHQL

  ORGANISATION_QUERY = CLIENT.parse <<-'GRAPHQL'
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
          admins(first: 1) {
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
      }
    }
  GRAPHQL

  OUTSIDE_COLLABORATOR_QUERY = CLIENT.parse <<-'GRAPHQL'
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

  REPOSITORY_QUERY = CLIENT.parse <<-'GRAPHQL'
    query ($login: String!, $name: String!) {
      organization(login: $login) {
        repository(name: $name) {
          createdAt
          description
          forkCount
          isArchived
          isEmpty
          isPrivate
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

  REPOSITORY_ACCESS_QUERY = CLIENT.parse <<-'GRAPHQL'
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

  TEAM_QUERY = CLIENT.parse <<-'GRAPHQL'
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

  TWO_FACTOR_DISABLED_USERS_QUERY = CLIENT.parse <<-'GRAPHQL'
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

  def initialize(enterprise, organisation, base_uri, token)
    @enterprise          = enterprise
    @organisation        = organisation
    @base_uri            = URI.parse(base_uri)
    @token               = token
    @two_factor_disabled = Set[]
  end

  def all_members
    after = nil
    next_page = true
    all_members = []

    while next_page
      members = CLIENT.query(ALL_MEMBERS_QUERY, variables: { slug: @enterprise, first: 100, after: after },
                                                context: { base_uri: @base_uri, token: @token })
      raise GitHubError, members.errors unless members.errors.empty?

      after = members.data.enterprise.members.page_info.end_cursor
      next_page = members.data.enterprise.members.page_info.has_next_page
      members.data.enterprise.members.nodes.each { |member| all_members << member }
    end

    all_members
  end

  def all_outside_collaborators
    after = nil
    next_page = true
    all_outside_collaborators = []

    while next_page
      collaborators = CLIENT.query(ALL_OUTSIDE_COLLABORATORS_QUERY, variables: { slug: @enterprise,
                                                                                 first: 100, after: after },
                                                                    context: { base_uri: @base_uri, token: @token })
      raise GitHubError, collaborators.errors unless collaborators.errors.empty?

      after = collaborators.data.enterprise.owner_info.outside_collaborators.page_info.end_cursor
      next_page = collaborators.data.enterprise.owner_info.outside_collaborators.page_info.has_next_page

      collaborators.data.enterprise.owner_info.outside_collaborators.edges.each do |collaborator|
        all_outside_collaborators << collaborator
      end
    end

    all_outside_collaborators
  end

  def all_teams
    after = nil
    next_page = true
    all_teams = []

    while next_page
      teams = CLIENT.query(ALL_TEAMS_QUERY, variables: { login: @organisation, first: 100, after: after },
                                            context: { base_uri: @base_uri, token: @token })
      raise GitHubError, teams.errors unless teams.errors.empty?

      after = teams.data.organization.teams.page_info.end_cursor
      next_page = teams.data.organization.teams.page_info.has_next_page
      teams.data.organization.teams.nodes.each { |team| all_teams << team }
    end

    all_teams
  end

  def outside_collaborator(login)
    outside_collaborator = CLIENT.query(OUTSIDE_COLLABORATOR_QUERY, variables: { slug: @enterprise, login: login },
                                                                    context: { base_uri: @base_uri, token: @token })
    raise GitHubError, outside_collaborator.errors unless outside_collaborator.errors.empty?

    outside_collaborator
  end

  def member(user_login)
    member = CLIENT.query(MEMBER_QUERY, variables: { slug: @enterprise, login: @organisation, user_login: user_login },
                                        context: { base_uri: @base_uri, token: @token })
    raise GitHubError, member.errors unless member.errors.empty?

    member
  end

  def organisation
    organisation = CLIENT.query(ORGANISATION_QUERY, variables: { login: @organisation, slug: @enterprise },
                                                    context: { base_uri: @base_uri, token: @token })
    raise GitHubError, organisation.errors unless organisation.errors.empty?

    organisation
  end

  def perform_two_factor_disabled_lookup
    after = nil
    next_page = true

    while next_page
      logins = CLIENT.query(TWO_FACTOR_DISABLED_QUERY, variables: { slug: @enterprise, first: 100, after: after },
                                                       context: { base_uri: @base_uri, token: @token })
      raise GitHubError, logins.errors unless logins.errors.empty?

      after = logins.data.enterprise.owner_info.affiliated_users_with_two_factor_disabled.page_info.end_cursor
      next_page = logins.data.enterprise.owner_info.affiliated_users_with_two_factor_disabled.page_info.has_next_page

      logins.data.enterprise.owner_info.affiliated_users_with_two_factor_disabled.nodes.each do |user|
        @two_factor_disabled << user.login
      end
    end
  end

  def repository(repository)
    repository = CLIENT.query(REPOSITORY_QUERY, variables: { login: @organisation, name: repository },
                                                context: { base_uri: @base_uri, token: @token })
    raise GitHubError, repository.errors unless repository.errors.empty?

    repository
  end

  def repository_access(repository)
    after = nil
    next_page = true
    repository_access = Set[]

    while next_page
      access = CLIENT.query(REPOSITORY_ACCESS_QUERY, variables: { login: @organisation, name: repository,
                                                                  first: 100, after: after },
                                                     context: { base_uri: @base_uri, token: @token })
      raise GitHubError, access.errors unless access.errors.empty?

      break if access.data.organization.repository.nil?

      after = access.data.organization.repository.collaborators.page_info.end_cursor
      next_page = access.data.organization.repository.collaborators.page_info.has_next_page

      access.data.organization.repository.collaborators.edges.each do |collaborator_edge|
        user_tuple = OpenStruct.new
        user_tuple.id     = collaborator_edge.node.login
        user_tuple.login  = collaborator_edge.node.login
        user_tuple.member = false
        user_tuple.name   = collaborator_edge.node.name

        collaborator_edge.node.organizations.nodes.each do |org|
          if org.name.eql?(access.data.organization.name)
            user_tuple.member = true
            break
          end
        end

        collaborator_edge.permission_sources.each do |permission_source|
          case permission_source.source.__typename
          when 'Organization'
            user_tuple.organisation_permission = permission_source.permission
          when 'Repository'
            user_tuple.repositor_name = permission_source.source.repository_name
            user_tuple.repository_permission = permission_source.permission
          when 'Team'
            user_tuple.team_parent     = permission_source.source.parent_team
            user_tuple.team_permission = permission_source.permission
            user_tuple.team_name = permission_source.source.team_name
            user_tuple.team_slug = permission_source.source.slug
          end
        end

        repository_access << user_tuple
      end
    end

    repository_access.sort_by(&:login)
  end

  def team(slug)
    after = nil
    next_page = true
    team_tuple = OpenStruct.new
    team_tuple.members = []

    while next_page
      team = CLIENT.query(TEAM_QUERY, variables: { login: @organisation, slug: slug,
                                                   first: 100, after: after },
                                      context: { base_uri: @base_uri, token: @token })
      raise GitHubError, team.errors unless team.errors.empty?

      after = team.data.organization.team.members.page_info.end_cursor
      next_page = team.data.organization.team.members.page_info.has_next_page

      team_tuple.avatar_url  = team.data.organization.team.avatar_url
      team_tuple.created_at  = team.data.organization.team.created_at
      team_tuple.description = team.data.organization.team.description
      team_tuple.name        = team.data.organization.team.name
      team_tuple.privacy     = team.data.organization.team.privacy
      team_tuple.updated_at  = team.data.organization.team.updated_at
      team_tuple.url         = team.data.organization.team.url

      unless team.data.organization.team.ancestors.nodes.nil?
        team_tuple.ancestors = team.data.organization.team.ancestors.nodes
      end

      unless team.data.organization.team.child_teams.nodes.nil?
        team_tuple.child_teams = team.data.organization.team.child_teams.nodes
      end

      team.data.organization.team.members.edges.each do |member|
        user_tuple = OpenStruct.new
        user_tuple.role  = member.role
        user_tuple.login = member.node.login
        user_tuple.name  = member.node.name
        team_tuple.members << user_tuple
      end
    end

    team_tuple.members.sort_by!(&:login)
    team_tuple
  end

  def two_factor_disabled_users
    after = nil
    next_page = true
    two_factor_disabled_users = []

    while next_page
      users = CLIENT.query(TWO_FACTOR_DISABLED_USERS_QUERY, variables: { login: @organisation, slug: @enterprise,
                                                                         first: 100, after: after },
                                                            context: { base_uri: @base_uri, token: @token })
      raise GitHubError, users.errors unless users.errors.empty?

      after = users.data.enterprise.owner_info.affiliated_users_with_two_factor_disabled.page_info.end_cursor
      next_page = users.data.enterprise.owner_info.affiliated_users_with_two_factor_disabled.page_info.has_next_page

      users.data.enterprise.owner_info.affiliated_users_with_two_factor_disabled.nodes.each do |user|
        user_tuple = OpenStruct.new
        user_tuple.avatar_url = user.avatar_url
        user_tuple.created_at = user.created_at
        user_tuple.email      = user.email
        user_tuple.login      = user.login
        user_tuple.member     = false
        user_tuple.name       = user.name
        user_tuple.updated_at = user.updated_at

        user.organizations.nodes.each do |org|
          if org.name.eql?(users.data.organization.name)
            user_tuple.member = true
            break
          end
        end

        two_factor_disabled_users << user_tuple
      end
    end

    two_factor_disabled_users
  end

  def two_factor_disabled?(login)
    @two_factor_disabled.each { |user_login| return true if user_login.eql?(login) }
    false
  end
end
