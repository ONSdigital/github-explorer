# frozen_string_literal: true

# Class representing an error received in response to making a request to GitHub's GraphQL API.
class GitHubError < StandardError
  attr_reader :response_body, :response_headers, :status_code

  def initialize(errors, response_body: nil, response_headers: nil, status_code: nil)
    message = response_body

    if !message && errors&.details
      data = errors.details['data']
      message = data&.first&.dig('message')
    end

    super(message)
    @errors = errors
    @response_body = response_body
    @response_headers = response_headers
    @status_code = status_code
  end

  def full_details
    details = {}
    details[:status_code] = @status_code if @status_code
    details[:response_body] = @response_body if @response_body
    details[:response_headers] = @response_headers if @response_headers
    details[:graphql_errors] = @errors.details if @errors&.details
    details
  end

  def message
    return @response_body if @response_body

    return unless @errors&.details

    data = @errors.details['data']
    data&.first&.dig('message')
  end

  def type
    return unless @errors&.details

    data = @errors.details['data']
    data&.first&.dig('type')
  end
end
