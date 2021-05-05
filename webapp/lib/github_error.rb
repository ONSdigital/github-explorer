# frozen_string_literal: true

# Class representing an error received in response to making a request to GitHub's GraphQL API.
class GitHubError < StandardError
  def initialize(errors)
    super
    @errors = errors
  end

  def message
    @errors.details['data'].first['message']
  end

  def type
    @errors.details['data'].first['type']
  end
end
