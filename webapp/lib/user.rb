# frozen_string_literal: true

# Class representing a GitHub user.
class User
  attr_reader :login,
              :name,
              :role

  attr_accessor :avatar_url,
                :created_at,
                :email,
                :member,
                :organisation_permission,
                :repository_name,
                :repository_permission,
                :team_parent,
                :team_permission,
                :team_name,
                :team_slug,
                :updated_at

  def initialize(login, name, member = false, role = nil)
    @login  = login
    @name   = name
    @member = member
    @role   = role
  end

  def id
    @login
  end
end
