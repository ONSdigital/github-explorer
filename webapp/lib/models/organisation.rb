# frozen_string_literal: true

# Model class representing a GitHub Organisation.
class Organisation
  attr_accessor :archived_repositories_count,
                :avatar_url,
                :location,
                :owners,
                :private_repositories_count,
                :public_repositories_count,
                :secret_teams_count,
                :sso_url,
                :template_repositories_count,
                :total_external_identities_count,
                :total_repositories_count,
                :total_teams_count,
                :visible_teams_count,
                :website_url

  attr_reader :created_at,
              :description,
              :name,
              :url

  attr_writer :identity_provider

  def initialize(name, description, url, created_at)
    @name        = name
    @description = description
    @url         = url
    @created_at  = created_at
  end

  def identity_provider?
    @identity_provider
  end
end