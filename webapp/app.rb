# frozen_string_literal: true

require 'logger'
require 'sinatra'
require 'ons-numbers'
require 'pagy'

require_relative 'lib/configuration'
require_relative 'lib/firestore_client'
require_relative 'lib/github'
require_relative 'lib/github_error'

include Pagy::Backend
Pagy::I18n.load(locale: 'en', filepath: 'locales/en.yml')

CONFIG    = Configuration.new(ENV)
FIRESTORE = FirestoreClient.new(CONFIG.firestore_project)
GITHUB    = GitHub.new(CONFIG.github_enterprise, CONFIG.github_organisation,
                       CONFIG.github_api_base_uri, CONFIG.github_token)
LOGGER    = Logger.new($stderr)

ACCESS_ITEMS_COUNT = 20
USERS_ITEMS_COUNT  = 10

set :github_organisation, CONFIG.github_organisation
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
  headers 'Content-Type' => 'text/html; charset=utf-8'
  @debug = true if params[:debug]
end

get '/?' do
  begin
    organisation = GITHUB.organisation.data
  rescue GitHubError => e
    return erb :github_error, locals: { title: 'GitHub Explorer', message: e.message, type: e.type }
  end

  pagy = Pagy.new(count: FIRESTORE.owners.count, page: (params[:page] || 1))
  owners = FIRESTORE.owners[pagy.offset, pagy.items]
  archived_repositories_count, template_repositories_count = FIRESTORE.archived_template_repositories_count
  two_factor_disabled_count = FIRESTORE.two_factor_disabled.count
  erb :index, locals: { title: "#{settings.github_organisation} - GitHub Explorer",
                        organisation:,
                        owners:,
                        archived_repositories_count:,
                        template_repositories_count:,
                        two_factor_disabled_count:,
                        pagy: }
end

get '/about' do
  branch = ENV.fetch('COMMIT_BRANCH', 'unknown')
  branch = 'main' if branch.empty?
  erb :about, locals: { title: 'About - GitHub Explorer',
                        branch:,
                        commit: ENV.fetch('COMMIT_SHA', 'unknown'),
                        repo_name: ENV.fetch('REPO_NAME') }
end

get '/collaborators/?' do
  begin
    all_outside_collaborators = GITHUB.all_outside_collaborators
  rescue GitHubError => e
    return erb :github_error, locals: { title: 'GitHub Explorer', message: e.message, type: e.type }
  end

  two_factor_disabled = FIRESTORE.two_factor_disabled
  erb :collaborators, locals: { title: 'Outside Collaborators - GitHub Explorer',
                                collaborators: all_outside_collaborators,
                                two_factor_disabled: }
end

get '/collaborators/:login' do |login|
  begin
    collaborator = GITHUB.outside_collaborator(login).data
  rescue GitHubError => e
    return erb :github_error, locals: { title: 'GitHub Explorer', message: e.message, type: e.type }
  end

  count = collaborator.enterprise.owner_info.outside_collaborators.edges.first.repositories.nodes.count
  pagy = Pagy.new(count:, items: USERS_ITEMS_COUNT, page: (params[:page] || 1))
  repos = collaborator.enterprise.owner_info.outside_collaborators.edges.first.repositories.nodes[pagy.offset, pagy.items]
  erb :collaborator, locals: { title: "#{login} Outside Collaborator - GitHub Explorer",
                               collaborator:,
                               two_factor_disabled: FIRESTORE.two_factor_disabled?(login),
                               repos:,
                               pagy: }
end

get '/contributions/?' do
  all_users_contributions = FIRESTORE.all_users_contributions
  erb :contributions, locals: { title: 'Contributions - GitHub Explorer',
                                contributions: all_users_contributions }
end

get '/health?' do
  halt 200
end

get '/inactive/?' do
  all_inactive_users  = FIRESTORE.all_inactive_users
  two_factor_disabled = FIRESTORE.two_factor_disabled
  erb :inactive, locals: { title: 'Inactive - GitHub Explorer',
                           inactive_users: all_inactive_users,
                           two_factor_disabled: }
end

get '/members/:login' do |login|
  begin
    member = GITHUB.member(login).data
  rescue GitHubError => e
    return erb :github_error, locals: { title: 'GitHub Explorer', message: e.message, type: e.type }
  end

  # The login string is converted to a symbol when returned from Firestore. Without this conversion the lookup fails.
  login_symbol = login.to_sym
  count = FIRESTORE.members_teams[login_symbol].nil? ? 0 : FIRESTORE.members_teams[login_symbol].count
  pagy = Pagy.new(count:, items: USERS_ITEMS_COUNT, page: (params[:page] || 1))
  teams = FIRESTORE.members_teams[login_symbol].to_a[pagy.offset, pagy.items]
  erb :member, locals: { title: "#{login} Member - GitHub Explorer",
                         member:,
                         owner: FIRESTORE.owner?(login),
                         two_factor_disabled: FIRESTORE.two_factor_disabled?(login),
                         teams:,
                         pagy: }
end

get '/members/?' do
  begin
    all_members = GITHUB.all_members
  rescue GitHubError => e
    return erb :github_error, locals: { title: 'GitHub Explorer', message: e.message, type: e.type }
  end

  two_factor_disabled = FIRESTORE.two_factor_disabled
  erb :members, locals: { title: 'Members - GitHub Explorer',
                          members: all_members,
                          two_factor_disabled: }
end

get '/repositories/?' do
  all_repositories = FIRESTORE.all_repositories
  erb :repositories, locals: { title: 'Repositories - GitHub Explorer',
                               repositories: all_repositories }
end

get '/repositories/archived' do
  archived_repositories = FIRESTORE.archived_repositories
  erb :repositories, locals: { title: 'Archived Repositories - GitHub Explorer',
                               repositories: archived_repositories }
end

get '/repositories/private' do
  private_repositories = FIRESTORE.private_repositories
  erb :repositories, locals: { title: 'Private/Internal Repositories - GitHub Explorer',
                               repositories: private_repositories }
end

get '/repositories/public' do
  public_repositories = FIRESTORE.public_repositories
  erb :repositories, locals: { title: 'Public Repositories - GitHub Explorer',
                               repositories: public_repositories }
end

get '/repositories/template' do
  template_repositories = FIRESTORE.template_repositories
  erb :repositories, locals: { title: 'Template Repositories - GitHub Explorer',
                               repositories: template_repositories }
end

get '/repositories/:repository' do |repository_slug|
  begin
    repository = GITHUB.repository(repository_slug).data

    unless repository.organization.repository.nil? || repository.organization.repository.is_archived
      repository_access = GITHUB.repository_access(repository_slug)
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
    all_teams = GITHUB.all_teams
  rescue GitHubError => e
    return erb :github_error, locals: { title: 'GitHub Explorer', message: e.message, type: e.type }
  end

  teamless_members = FIRESTORE.teamless_members.size
  erb :teams, locals: { title: 'Teams - GitHub Explorer',
                        teams: all_teams,
                        teamless_members: }
end

get '/teams/:team' do |team|
  begin
    team = GITHUB.team(team)
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
  two_factor_disabled = FIRESTORE.two_factor_disabled
  erb :teamless, locals: { title: 'Teamless Members - GitHub Explorer',
                           teamless_members: FIRESTORE.teamless_members,
                           two_factor_disabled: }
end

get '/two-factor-security/?' do
  begin
    two_factor_disabled_users = GITHUB.two_factor_disabled_users
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
