# frozen_string_literal: true

# Class representing an error received in response to making a request to GitHub's GraphQL API.
class GitHubError < StandardError
  def initialize(errors)
    super
    @errors = errors
  end

  def location_column
    @errors.details['data'].first['locations'].first['column']
  end

  def location_line
    @errors.details['data'].first['locations'].first['line']
  end

  def message
    @errors.details['data'].first['message']
  end

  def path
    @errors.details['data'].first['path'].join('/')
  end

  def type
    @errors.details['data'].first['type']
  end
end
