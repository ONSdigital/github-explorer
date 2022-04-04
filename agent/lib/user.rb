# frozen_string_literal: true

# Class representing a GitHub user.
class User
  attr_reader :login,
              :name

  attr_accessor :avatar_url,
                :commit_contributions,
                :created_at,
                :email,
                :has_contributions,
                :issue_contributions,
                :member,
                :pull_request_contributions,
                :restricted_contributions,
                :updated_at

  def initialize(login, name)
    @login = login
    @name  = name
  end
end
