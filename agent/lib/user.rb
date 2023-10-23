# frozen_string_literal: true

# Class representing a GitHub user.
class User
  attr_reader :login,
              :name

  attr_accessor :avatar_url,
                :commit_contributions,
                :created_at,
                :domain_emails,
                :email,
                :has_contributions,
                :issue_contributions,
                :member,
                :organisations,
                :pull_request_contributions,
                :restricted_contributions,
                :updated_at

  def initialize(login, name)
    @login = login
    @name  = name
  end

  def to_h
    {
      avatar_url: @avatar_url,
      commit_contributions: @commit_contributions,
      created_at: @created_at,
      domain_emails: @domain_emails,
      email: @email,
      has_contributions: @has_contributions,
      issue_contributions: @issue_contributions,
      login: @login,
      member: @member,
      name: @name,
      organisations: @organisations,
      pull_request_contributions: @pull_request_contributions,
      restricted_contributions: @restricted_contributions,
      updated_at: @updated_at
    }.compact!
  end
end
