# frozen_string_literal: true

# Simple class to centralise access to configuration.
class Configuration
  attr_reader :firestore_project,
              :github_api_base_uri,
              :github_enterprise,
              :github_organisations,
              :github_token,
              :github_variant

  GITHUB_VARIANTS = %w[github github-enterprise-server].freeze

  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity,  Metrics/MethodLength, Layout/LineLength
  def initialize(env)
    @content_security_policy_image_sources  = env['CONTENT_SECURITY_POLICY_IMAGE_SOURCES']
    @content_security_policy_script_sources = env['CONTENT_SECURITY_POLICY_SCRIPT_SOURCES']
    @content_security_policy_style_sources  = env['CONTENT_SECURITY_POLICY_STYLE_SOURCES']
    @firestore_project                      = env['FIRESTORE_PROJECT']
    @github_api_base_uri                    = env['GITHUB_API_BASE_URI']
    @github_enterprise                      = env['GITHUB_ENTERPRISE_NAME']
    @github_organisations                   = env['GITHUB_ORGANISATIONS']
    @github_token                           = env['GITHUB_TOKEN']
    @github_variant                         = env['GITHUB_VARIANT']

    raise 'Missing CONTENT_SECURITY_POLICY_IMAGE_SOURCES environment variable' unless @content_security_policy_image_sources
    raise 'Missing CONTENT_SECURITY_POLICY_SCRIPT_SOURCES environment variable' unless @content_security_policy_script_sources
    raise 'Missing CONTENT_SECURITY_POLICY_STYLE_SOURCES environment variable' unless @content_security_policy_style_sources
    raise 'Missing FIRESTORE_PROJECT environment variable' unless @firestore_project
    raise 'Missing GITHUB_API_BASE_URI environment variable' unless @github_api_base_uri
    raise 'Missing GITHUB_ENTERPRISE_NAME environment variable' unless @github_enterprise
    raise 'Missing GITHUB_ORGANISATIONS environment variable' unless @github_organisations
    raise 'Missing GITHUB_TOKEN environment variable' unless @github_token
    raise 'Missing GITHUB_VARIANT environment variable' unless @github_variant
    raise 'Invalid GITHUB_VARIANT environment variable' unless GITHUB_VARIANTS.include?(@github_variant)
  end
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity,  Metrics/MethodLength, Layout/LineLength

  def content_security_policy_image_sources
    @content_security_policy_image_sources.split(',').join(' ')
  end

  def content_security_policy_script_sources
    @content_security_policy_script_sources.split(',').join(' ')
  end

  def content_security_policy_style_sources
    @content_security_policy_style_sources.split(',').join(' ')
  end
end
