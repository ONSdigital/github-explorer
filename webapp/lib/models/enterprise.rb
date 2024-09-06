# frozen_string_literal: true

# Model class representing a GitHub Enterprise.
class Enterprise
  attr_accessor :administrators,
                :avatar_url,
                :location,
                :pending_members_count,
                :total_available_licences_count,
                :total_licences_count,
                :total_members_count,
                :total_outside_collaborators_count,
                :two_factor_security_disabled_count,
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
