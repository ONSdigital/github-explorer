# frozen_string_literal: true

class GitHubError < StandardError
  def initialize(errors)
    @errors = errors
  end

  def message
    @errors.details['data'].first['message']
  end

  def type
    @errors.details['data'].first['type']
  end
end
