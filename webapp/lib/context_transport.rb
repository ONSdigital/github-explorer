# frozen_string_literal: true

require 'graphql/client'
require 'graphql/client/http'

# See https://github.com/github/graphql-client/issues/257
class ContextTransport < GraphQL::Client::HTTP
  def initialize
    super('https://localhost:1234')
  end

  def headers(context)
    {
      'Authorization': "Bearer #{context.fetch(:token)}",
      'Accept-Encoding': 'gzip'
    }
  end

  def execute(document:, operation_name: nil, variables: {}, context: {})
    @uri = context.fetch(:base_uri) + '/graphql'
    super(document: document, operation_name: operation_name, variables: variables, context: context)
  end
end
