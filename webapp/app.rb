# frozen_string_literal: true

require 'logger'
require 'sinatra'
require "sinatra/cookies"
require 'ons-numbers'
require 'pagy'

require_relative 'lib/configuration'
require_relative 'lib/firestore_client'
require_relative 'lib/github'
require_relative 'lib/github_error'

include Pagy::Backend
Pagy::I18n.load(locale: 'en', filepath: 'locales/en.yml')

CONFIG = Configuration.new(ENV)
LOGGER = Logger.new($stderr)

ACCESS_ITEMS_COUNT = 20
USERS_ITEMS_COUNT  = 10

set :logging, false # Stop Sinatra logging routes to STDERR.

helpers do
  include Pagy::Frontend

  def d(text)
    Time.parse(text).utc.strftime('%d %b %Y %H:%M')
  end

  def h(text)
    Rack::Utils.escape_html(text)
  end

  def n(number)
    Numbers.grouped(number)
  end

  def pagination_links(pagy)
    pagy_nav(pagy) if pagy.pages > 1
  end

  def percentage(number, total)
    Numbers.percentage(number, total)
  end

  def pluralise(count, singular_noun, plural_noun = nil)
    count == 1 ? "1 #{singular_noun}" : plural_noun.nil? ? "#{n(count)} #{singular_noun}s" : "#{n(count)} #{plural_noun}"
  end

  def website_link(url)
    link = url
    link = "http://#{url}" unless url.start_with?('http')
    link
  end
end

before do
  headers 'Cache-Control' => 'no-cache'
  headers 'Content-Security-Policy' => "default-src 'self'; img-src 'self' data: https://avatars.githubusercontent.com https://cdn.datatables.net; https://githubdev-explorer.integrateddataservice.gov.uk; script-src 'unsafe-eval' 'self' https://ajax.googleapis.com https://cdn.datatables.net https://cdnjs.cloudflare.com; style-src 'self' 'unsafe-inline' https://cdn.datatables.net;"
  headers 'Content-Type' => 'text/html; charset=utf-8'
  headers 'Permissions-Policy' => 'fullscreen=(self)'
  headers 'Referrer-Policy' => 'strict-origin-when-cross-origin'
  headers 'Strict-Transport-Security' => 'max-age=63072000; includeSubDomains; preload'
  headers 'X-Content-Type-Options' => 'nosniff'
  headers 'X-Frame-Options' => 'deny'
  headers 'X-XSS-Protection' => '1; mode=block'
  @organisations = CONFIG.github_organisations.split(',')
  @selected_organisation = cookies['github-explorer-organisation'] || @organisations.first
  @firestore = FirestoreClient.new(CONFIG.firestore_project, @selected_organisation)
end

get '/?' do
  begin
    github = GitHub.new(CONFIG.github_enterprise, @selected_organisation,
                        CONFIG.github_api_base_uri, CONFIG.github_token)

    organisation = github.organisation.data
  rescue GitHubError => e
    return erb :github_error, locals: { title: 'GitHub Explorer', message: e.message, type: e.type }
  end

  pagy = Pagy.new(count: @firestore.all_owners.count, page: (params[:page] || 1))
  owners = @firestore.all_owners[pagy.offset, pagy.items]
  archived_repositories_count, template_repositories_count = @firestore.archived_template_repositories_count
  two_factor_disabled_count = @firestore.all_two_factor_disabled.count
  erb :index, locals: { title: "#{@selected_organisation} - GitHub Explorer",
                        organisation:,
                        owners:,
                        archived_repositories_count:,
                        template_repositories_count:,
                        two_factor_disabled_count:,
                        pagy: }
end

get '/about' do
  github = GitHub.new(CONFIG.github_enterprise, @selected_organisation,
                      CONFIG.github_api_base_uri, CONFIG.github_token)

  branch = ENV.fetch('COMMIT_BRANCH', 'unknown')
  branch = 'main' if branch.empty?
  all_inactive_users_updated      = @firestore.all_inactive_users_updated
  all_members_teams_updated       = @firestore.all_members_teams_updated
  all_members_updated             = @firestore.all_members_updated
  all_owners_updated              = @firestore.all_owners_updated
  all_repositories_updated        = @firestore.all_repositories_updated
  all_two_factor_disabled_updated = @firestore.all_two_factor_disabled_updated
  all_users_contributions_updated = @firestore.all_users_contributions_updated
  teamless_members_updated        = @firestore.teamless_members_updated

  erb :about, locals: { title: 'About - GitHub Explorer',
                        rate_limit: github.rate_limit.data.rate_limit,
                        branch:,
                        commit: ENV.fetch('COMMIT_SHA', 'unknown'),
                        repo_name: ENV.fetch('REPO_NAME'),
                        all_inactive_users_updated:,
                        all_members_teams_updated:,
                        all_members_updated:,
                        all_owners_updated:,
                        all_repositories_updated:,
                        all_two_factor_disabled_updated:,
                        all_users_contributions_updated:,
                        teamless_members_updated: }
end

get '/collaborators/?' do
  begin
    github = GitHub.new(CONFIG.github_enterprise, @selected_organisation,
                        CONFIG.github_api_base_uri, CONFIG.github_token)

    all_outside_collaborators = github.all_outside_collaborators
  rescue GitHubError => e
    return erb :github_error, locals: { title: 'GitHub Explorer', message: e.message, type: e.type }
  end

  two_factor_disabled = @firestore.all_two_factor_disabled
  erb :collaborators, locals: { title: 'Outside Collaborators - GitHub Explorer',
                                collaborators: all_outside_collaborators,
                                two_factor_disabled: }
end

get '/collaborators/:login' do |login|
  begin
    github = GitHub.new(CONFIG.github_enterprise, @selected_organisation,
                        CONFIG.github_api_base_uri, CONFIG.github_token)

    collaborator = github.outside_collaborator(login).data
  rescue GitHubError => e
    return erb :github_error, locals: { title: 'GitHub Explorer', message: e.message, type: e.type }
  end

  count = collaborator.enterprise.owner_info.outside_collaborators.edges&.first&.repositories&.nodes&.count || 0
  pagy  = Pagy.new(count:, items: USERS_ITEMS_COUNT, page: (params[:page] || 1))
  contributions = @firestore.user_contributions(login).first
  repos = []

  unless collaborator.enterprise.owner_info.outside_collaborators.edges.empty?
    repos = collaborator.enterprise.owner_info.outside_collaborators.edges.first.repositories.nodes[pagy.offset, pagy.items]
  end

  erb :collaborator, locals: { title: "#{login} Outside Collaborator - GitHub Explorer",
                               collaborator:,
                               contributions:,
                               login:,
                               two_factor_disabled: @firestore.two_factor_disabled?(login),
                               repos:,
                               pagy: }
end

get '/contributions/?' do
  all_users_contributions = @firestore.all_users_contributions
  erb :contributions, locals: { title: 'Contributions - GitHub Explorer',
                                contributions: all_users_contributions }
end

get '/health?' do
  halt 200
end

get '/inactive/?' do
  all_inactive_users  = @firestore.all_inactive_users
  two_factor_disabled = @firestore.all_two_factor_disabled
  erb :inactive, locals: { title: 'Inactive - GitHub Explorer',
                           inactive_users: all_inactive_users,
                           two_factor_disabled: }
end

# Note that this route has to appear above /members/:login to prevent "organisation" getting matched as a login name.
get '/members/organisation' do
  erb :members, locals: { title: 'Organisation Members - GitHub Explorer',
                          members: @firestore.all_organisation_members,
                          two_factor_disabled: @firestore.all_two_factor_disabled }
end

get '/members/:login' do |login|
  begin
    github = GitHub.new(CONFIG.github_enterprise, @selected_organisation,
                        CONFIG.github_api_base_uri, CONFIG.github_token)

    member = github.member(login).data
  rescue GitHubError => e
    return erb :github_error, locals: { title: 'GitHub Explorer', message: e.message, type: e.type }
  end

  # The login string is converted to a symbol when returned from Firestore. Without this conversion the lookup fails.
  login_symbol = login.to_sym
  count = @firestore.all_members_teams[login_symbol].nil? ? 0 : @firestore.all_members_teams[login_symbol].count
  pagy = Pagy.new(count:, items: USERS_ITEMS_COUNT, page: (params[:page] || 1))
  contributions = @firestore.user_contributions(login).first
  teams = @firestore.all_members_teams[login_symbol].to_a[pagy.offset, pagy.items]
  erb :member, locals: { title: "#{login} Member - GitHub Explorer",
                         contributions:,
                         login:,
                         member:,
                         owner: @firestore.owner?(login),
                         two_factor_disabled: @firestore.two_factor_disabled?(login),
                         teams:,
                         pagy: }
end

get '/members/?' do
  erb :members, locals: { title: 'Members - GitHub Explorer',
                          members: @firestore.all_members,
                          two_factor_disabled: @firestore.all_two_factor_disabled }
end

get '/repositories/?' do
  all_repositories = @firestore.all_repositories
  erb :repositories, locals: { title: 'Repositories - GitHub Explorer',
                               repositories: all_repositories }
end

get '/repositories/archived' do
  archived_repositories = @firestore.archived_repositories
  erb :repositories, locals: { title: 'Archived Repositories - GitHub Explorer',
                               repositories: archived_repositories }
end

get '/repositories/private' do
  private_repositories = @firestore.private_repositories
  erb :repositories, locals: { title: 'Private/Internal Repositories - GitHub Explorer',
                               repositories: private_repositories }
end

get '/repositories/public' do
  public_repositories = @firestore.public_repositories
  erb :repositories, locals: { title: 'Public Repositories - GitHub Explorer',
                               repositories: public_repositories }
end

get '/repositories/template' do
  template_repositories = @firestore.template_repositories
  erb :repositories, locals: { title: 'Template Repositories - GitHub Explorer',
                               repositories: template_repositories }
end

get '/repositories/:repository' do |repository_slug|
  begin
    github = GitHub.new(CONFIG.github_enterprise, @selected_organisation,
                        CONFIG.github_api_base_uri, CONFIG.github_token)

    repository = github.repository(repository_slug).data

    unless repository.organization.repository.nil? || repository.organization.repository.is_archived
      repository_access = github.repository_access(repository_slug)
      pagy = Pagy.new(count: repository_access.count, items: ACCESS_ITEMS_COUNT, page: (params[:page] || 1))
      access = repository_access[pagy.offset, pagy.items]
    end

    repo = repository.organization.repository
  rescue GitHubError => e
    return erb :github_error, locals: { title: 'GitHub Explorer', message: e.message, type: e.type }
  end

  erb :repository, locals: { title: "#{repository_slug} Repository - GitHub Explorer",
                             repository_slug:,
                             repo:,
                             access:,
                             pagy: }
end

get '/teams/?' do
  begin
    github = GitHub.new(CONFIG.github_enterprise, @selected_organisation,
                        CONFIG.github_api_base_uri, CONFIG.github_token)

    all_teams = github.all_teams
  rescue GitHubError => e
    return erb :github_error, locals: { title: 'GitHub Explorer', message: e.message, type: e.type }
  end

  teamless_members = @firestore.teamless_members.size
  erb :teams, locals: { title: 'Teams - GitHub Explorer',
                        teams: all_teams,
                        teamless_members: }
end

get '/teams/secret' do
  begin
    github = GitHub.new(CONFIG.github_enterprise, @selected_organisation,
                        CONFIG.github_api_base_uri, CONFIG.github_token)

    secret_teams = github.secret_teams
  rescue GitHubError => e
    return erb :github_error, locals: { title: 'GitHub Explorer', message: e.message, type: e.type }
  end

  teamless_members = @firestore.teamless_members.size
  erb :teams, locals: { title: 'Secret Teams - GitHub Explorer',
                        teams: secret_teams,
                        teamless_members: }
end

get '/teams/visible' do
  begin
    github = GitHub.new(CONFIG.github_enterprise, @selected_organisation,
                        CONFIG.github_api_base_uri, CONFIG.github_token)

    visible_teams = github.visible_teams
  rescue GitHubError => e
    return erb :github_error, locals: { title: 'GitHub Explorer', message: e.message, type: e.type }
  end

  teamless_members = @firestore.teamless_members.size
  erb :teams, locals: { title: 'Visible Teams - GitHub Explorer',
                        teams: visible_teams,
                        teamless_members: }
end

get '/teams/:team' do |team|
  begin
    github = GitHub.new(CONFIG.github_enterprise, @selected_organisation,
                        CONFIG.github_api_base_uri, CONFIG.github_token)

    team = github.team(team)
  rescue GitHubError => e
    return erb :github_error, locals: { title: 'GitHub Explorer', message: e.message, type: e.type }
  end

  pagy = Pagy.new(count: team.members.count, page: (params[:page] || 1))
  members = team.members[pagy.offset, pagy.items]
  erb :team, locals: { title: "#{team.name} Team - GitHub Explorer",
                       team:,
                       members:,
                       pagy: }
end

get '/teamless' do
  two_factor_disabled = @firestore.all_two_factor_disabled
  erb :teamless, locals: { title: 'Teamless Members - GitHub Explorer',
                           teamless_members: @firestore.teamless_members,
                           two_factor_disabled: }
end

get '/two-factor-security/?' do
  begin
    github = GitHub.new(CONFIG.github_enterprise, @selected_organisation,
                        CONFIG.github_api_base_uri, CONFIG.github_token)

    two_factor_disabled_users = github.two_factor_disabled_users
  rescue GitHubError => e
    return erb :github_error, locals: { title: 'GitHub Explorer', message: e.message, type: e.type }
  end

  erb :two_factor, locals: { title: '2FA Security - GitHub Explorer',
                             users: two_factor_disabled_users }
end

error do
  LOGGER.error(env['sinatra.error'].message)
  LOGGER.error(env['sinatra.error'].backtrace.join("\n"))

  erb :error, locals: { title: '500 Internal Server Error - GitHub Explorer' }
end

not_found do
  erb :not_found, locals: { title: '404 Not Found - GitHub Explorer' }
end
