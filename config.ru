# frozen_string_literal: true

require_relative 'app'

use Rack::ETag
use Rack::ConditionalGet
use Rack::Deflater

run Sinatra::Application
