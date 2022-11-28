# frozen_string_literal: true

# Simple class to centralise access to configuration.
class Configuration
  attr_reader :firestore_project,
              :github_api_base_uri,
              :github_enterprise,
              :github_organisation,
              :github_organisations,
              :github_token

  def initialize(env)
    @firestore_project    = env['FIRESTORE_PROJECT']
    @github_api_base_uri  = env['GITHUB_API_BASE_URI']
    @github_enterprise    = env['GITHUB_ENTERPRISE_NAME']
    @github_organisation  = env['GITHUB_ORGANISATION_NAME']
    @github_organisations = env['GITHUB_ORGANISATIONS']
    @github_token         = env['GITHUB_TOKEN']

    raise 'Missing FIRESTORE_PROJECT environment variable' unless @firestore_project
    raise 'Missing GITHUB_API_BASE_URI environment variable' unless @github_api_base_uri
    raise 'Missing GITHUB_ENTERPRISE_NAME environment variable' unless @github_enterprise
    raise 'Missing GITHUB_ORGANISATION_NAME environment variable' unless @github_organisation
    raise 'Missing GITHUB_ORGANISATIONS environment variable' unless @github_organisations
    raise 'Missing GITHUB_TOKEN environment variable' unless @github_token
  end
end
