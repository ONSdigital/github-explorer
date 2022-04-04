# frozen_string_literal: true

# Class representing a GitHub team.
class Team
  attr_accessor :ancestors,
                :avatar_url,
                :child_teams,
                :created_at,
                :description,
                :members,
                :name,
                :privacy,
                :updated_at,
                :url

  def initialize
    @members = []
  end

  def has_parent_team?
    @ancestors.size.positive?
  end
end
