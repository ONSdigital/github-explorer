# frozen_string_literal: true

require 'ostruct'
require 'graphql/client'
require 'graphql/client/http'

require_relative 'context_transport'
require_relative 'github_error'

# Class that encapsulates access to the GitHub GraphQL API.
class GitHub
  attr_reader :members_teams, :owners, :two_factor_disabled

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

  ALL_TEAMS_ALL_MEMBERS_QUERY = CLIENT.parse <<-'GRAPHQL'
    query($login: String!) {
      organization(login: $login) {
        teams(first: 100) {
          nodes {
            name
            privacy
            slug
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
    query($slug: String!, $login: String!) {
      enterprise(slug: $slug) {
        members(first: 1, query: $login) {
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
              permissionSources {
                permission
                source {
                  ... on Team {
                    avatarUrl
                    name
                    members(first: 1, membership: IMMEDIATE) {
                      totalCount
                    }
                    parentTeam {
                      name
                    }
                  }
                }
              }
              node {
                avatarUrl
                login
                name
                organizations(first: 5) {
                  nodes {
                    name
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

  def initialize(base_uri, token)
    @base_uri = URI.parse(base_uri)
    @token    = token
    @members_teams       = {}
    @owners              = Set[]
    @two_factor_disabled = Set[]
  end

  def all_members(enterprise)
    after = nil
    next_page = true
    all_members = []

    while next_page
      members = CLIENT.query(ALL_MEMBERS_QUERY, variables: { slug: enterprise, first: 100, after: after },
                                                context: { base_uri: @base_uri, token: @token })
      raise GitHubError, members.errors unless members.errors.empty?

      after = members.data.enterprise.members.page_info.end_cursor
      next_page = members.data.enterprise.members.page_info.has_next_page
      members.data.enterprise.members.nodes.each { |member| all_members << member }
    end

    all_members
  end

  def all_outside_collaborators(enterprise)
    after = nil
    next_page = true
    all_outside_collaborators = []

    while next_page
      collaborators = CLIENT.query(ALL_OUTSIDE_COLLABORATORS_QUERY, variables: { slug: enterprise,
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

  def all_repositories(organisation)
    after = nil
    next_page = true
    all_repositories = []

    while next_page
      repositories = CLIENT.query(ALL_REPOSITORIES_QUERY, variables: { login: organisation, first: 100, after: after },
                                                          context: { base_uri: @base_uri, token: @token })
      raise GitHubError, repositories.errors unless repositories.errors.empty?

      after = repositories.data.organization.repositories.page_info.end_cursor
      next_page = repositories.data.organization.repositories.page_info.has_next_page

      repositories.data.organization.repositories.nodes.each { |repository| all_repositories << repository }
    end

    all_repositories
  end

  def all_teams(organisation)
    after = nil
    next_page = true
    all_teams = []

    while next_page
      teams = CLIENT.query(ALL_TEAMS_QUERY, variables: { login: organisation, first: 100, after: after },
                                            context: { base_uri: @base_uri, token: @token })
      raise GitHubError, teams.errors unless teams.errors.empty?

      after = teams.data.organization.teams.page_info.end_cursor
      next_page = teams.data.organization.teams.page_info.has_next_page
      teams.data.organization.teams.nodes.each { |team| all_teams << team }
    end

    all_teams
  end

  def outside_collaborator(enterprise, login)
    outside_collaborator = CLIENT.query(OUTSIDE_COLLABORATOR_QUERY, variables: { slug: enterprise, login: login },
                                                                    context: { base_uri: @base_uri, token: @token })
    raise GitHubError, outside_collaborator.errors unless outside_collaborator.errors.empty?

    outside_collaborator
  end

  def owner?(login)
    @owners.each { |owner| return true if owner.login.eql?(login) }
    false
  end

  def member(enterprise, login)
    member = CLIENT.query(MEMBER_QUERY, variables: { slug: enterprise, login: login },
                                        context: { base_uri: @base_uri, token: @token })
    raise GitHubError, member.errors unless member.errors.empty?

    member
  end

  def perform_member_role_lookup(organisation)
    after = nil
    next_page = true

    while next_page
      members = CLIENT.query(ALL_MEMBERS_WITH_ROLES_QUERY, variables: { login: organisation, first: 100, after: after },
                                                           context: { base_uri: @base_uri, token: @token })
      raise GitHubError, members.errors unless members.errors.empty?

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
    raise GitHubError, teams.errors unless teams.errors.empty?

    teams.data.organization.teams.nodes.each do |team|
      team_tuple = OpenStruct.new
      team_tuple.name    = team.name
      team_tuple.privacy = team.privacy
      team_tuple.slug    = team.slug

      team.members.nodes.each do |member|
        if @members_teams.key?(member.login)
          @members_teams[member.login] << team_tuple
        else
          @members_teams[member.login] = Set[team_tuple]
        end
      end
    end
  end

  def perform_two_factor_disabled_lookup(enterprise)
    after = nil
    next_page = true

    while next_page
      logins = CLIENT.query(TWO_FACTOR_DISABLED_QUERY, variables: { slug: enterprise, first: 100, after: after },
                                                       context: { base_uri: @base_uri, token: @token })
      raise GitHubError, logins.errors unless logins.errors.empty?

      after = logins.data.enterprise.owner_info.affiliated_users_with_two_factor_disabled.page_info.end_cursor
      next_page = logins.data.enterprise.owner_info.affiliated_users_with_two_factor_disabled.page_info.has_next_page

      logins.data.enterprise.owner_info.affiliated_users_with_two_factor_disabled.nodes.each do |user|
        @two_factor_disabled << user.login
      end
    end
  end

  def repository(organisation, repository)
    repository = CLIENT.query(REPOSITORY_QUERY, variables: { login: organisation, name: repository },
                                                context: { base_uri: @base_uri, token: @token })
    raise GitHubError, repository.errors unless repository.errors.empty?

    repository
  end

  def repository_access(organisation, repository)
    after = nil
    next_page = true
    repository_access = Set[]

    while next_page
      access = CLIENT.query(REPOSITORY_ACCESS_QUERY, variables: { login: organisation, name: repository,
                                                                  first: 100, after: after },
                                                     context: { base_uri: @base_uri, token: @token })
      raise GitHubError, access.errors unless access.errors.empty?

      after = access.data.organization.repository.collaborators.page_info.end_cursor
      next_page = access.data.organization.repository.collaborators.page_info.has_next_page

      access.data.organization.repository.collaborators.edges.each do |collaborator_edge|
        collaborator_edge.permission_sources.each do |permission_source|
          # Ignore organisations and repositories and child teams.
          if permission_source.source.__typename.eql?('Team') && permission_source.source.parent_team.nil?
            team_tuple = OpenStruct.new
            team_tuple.id           = permission_source.source.name
            team_tuple.avatar_url   = permission_source.source.avatar_url
            team_tuple.name         = permission_source.source.name
            team_tuple.member_count = permission_source.source.members.total_count
            team_tuple.permission   = permission_source.permission
            team_tuple.type         = 'team'
            repository_access << team_tuple
          end
        end

        user_tuple = OpenStruct.new
        user_tuple.id         = collaborator_edge.node.login
        user_tuple.avatar_url = collaborator_edge.node.avatar_url
        user_tuple.login      = collaborator_edge.node.login
        user_tuple.member     = false
        user_tuple.name       = collaborator_edge.node.name
        user_tuple.permission = collaborator_edge.permission_sources.first.permission
        user_tuple.type       = 'user'

        collaborator_edge.node.organizations.nodes.each do |org|
          if org.name.eql?(access.data.organization.name)
            user_tuple.member = true
            break
          end
        end

        # Only add users who are outside collaborators i.e. not members.
        repository_access << user_tuple unless user_tuple.member
      end
    end

    repository_access
  end

  def summary(enterprise, organisation)
    summary = CLIENT.query(SUMMARY_QUERY, variables: { login: organisation, slug: enterprise },
                                          context: { base_uri: @base_uri, token: @token })
    raise GitHubError, summary.errors unless summary.errors.empty?

    summary
  end

  def team(organisation, slug)
    after = nil
    next_page = true
    team_tuple = OpenStruct.new
    team_tuple.members = []

    while next_page
      team = CLIENT.query(TEAM_QUERY, variables: { login: organisation, slug: slug,
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

  def two_factor_disabled_users(enterprise, organisation)
    after = nil
    next_page = true
    two_factor_disabled_users = []

    while next_page
      users = CLIENT.query(TWO_FACTOR_DISABLED_USERS_QUERY, variables: { login: organisation, slug: enterprise,
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
