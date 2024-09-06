# frozen_string_literal: true

# Model class representing a GitHub Organisation.
class Organisation
  attr_accessor :archived_repositories_count,
                :avatar_url,
                :identity_provider?,
                :identity_provider_total_external_identities_count,
                :identity_provider_sso_url,
                :location,
                :owners,
                :private_repositories_count,
                :public_repositories_count,
                :secret_teams_count,
                :template_repositories_count,
                :total_repositories_count,
                :total_teams_count,
                :visible_teams_count,
                :website_url

  attr_reader :created_at,
              :description,
              :name,
              :url

  def initialize(name, description, url, created_at)
    @name        = name
    @description = description
    @url         = url
    @created_at  = created_at
  end
end
