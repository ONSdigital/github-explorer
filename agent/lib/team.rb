# frozen_string_literal: true

# Class representing a GitHub team.
class Team
  attr_reader :name,
              :privacy,
              :slug

  def initialize(name, privacy, slug)
    @name    = name
    @privacy = privacy
    @slug    = slug
  end

  def to_h
    { name: @name, privacy: @privacy, slug: @slug }
  end
end
