# frozen_string_literal: true

# This module contains the GraphQL queries used by the GraphQL client class.
module GraphQLQueries
  ENTERPRISE_AND_ORGANISATION_QUERY = <<-GRAPHQL
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
end
