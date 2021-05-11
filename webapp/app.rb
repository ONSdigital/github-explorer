# frozen_string_literal: true

require 'sinatra'
require 'sinatra/partial'
require 'pagy'

require_relative 'lib/configuration'
require_relative 'lib/firestore'
require_relative 'lib/github'
require_relative 'lib/github_error'

set :partial_template_engine, :erb

include Pagy::Backend
Pagy::I18n.load(locale: 'en', filepath: 'locales/en.yml')

CONFIG    = Configuration.new(ENV)
FIRESTORE = Firestore.new(CONFIG.firestore_project)
GITHUB    = GitHub.new(CONFIG.github_enterprise, CONFIG.github_organisation,
                       CONFIG.github_api_base_uri, CONFIG.github_token)
ACCESS_ITEMS_COUNT = 20
ITEMS_COUNT        = 40
USERS_ITEMS_COUNT  = 10

set :github_organisation, CONFIG.github_organisation

helpers do
  include Pagy::Frontend

  def d(text)
    Time.parse(text).utc.strftime('%d %b %Y %H:%M')
  end

  def h(text)
    Rack::Utils.escape_html(text)
  end

  def n(count)
    count_groups = count.to_s.chars.to_a.reverse.each_slice(3)
    count_groups.map(&:join).join(',').reverse
  end

  def pagination_links(pagy)
    pagy_nav(pagy) if pagy.pages > 1
  end

  def percentage(num, total)
    "#{((num.to_f / total) * 100).round(2)}%"
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
    GITHUB.perform_member_role_lookup
    GITHUB.perform_two_factor_disabled_lookup
    organisation = GITHUB.organisation.data
  rescue GitHubError => e
    return erb :github_error, locals: { title: 'GitHub Explorer', message: e.message, type: e.type }
  end

  pagy = Pagy.new(count: GITHUB.owners.count, page: (params[:page] || 1))
  owners = GITHUB.owners.sort_by(&:login)[pagy.offset, pagy.items]
  two_factor_disabled_count = GITHUB.two_factor_disabled.count
  erb :index, locals: { title: "#{settings.github_organisation} - GitHub Explorer",
                        organisation: organisation,
                        owners: owners,
                        two_factor_disabled_count: two_factor_disabled_count,
                        pagy: pagy }
end

get '/collaborators/?' do
  begin
    all_outside_collaborators = GITHUB.all_outside_collaborators
  rescue GitHubError => e
    return erb :github_error, locals: { title: 'GitHub Explorer', message: e.message, type: e.type }
  end

  pagy = Pagy.new(count: all_outside_collaborators.count, items: ITEMS_COUNT, page: (params[:page] || 1))
  collaborators = all_outside_collaborators[pagy.offset, pagy.items]
  erb :collaborators, locals: { title: 'Outside Collaborators - GitHub Explorer',
                                collaborators: collaborators,
                                pagy: pagy }
end

get '/collaborators/:login' do |login|
  begin
    collaborator = GITHUB.outside_collaborator(login).data
  rescue GitHubError => e
    return erb :github_error, locals: { title: 'GitHub Explorer', message: e.message, type: e.type }
  end

  count = collaborator.enterprise.owner_info.outside_collaborators.edges.first.repositories.nodes.count
  pagy = Pagy.new(count: count, items: USERS_ITEMS_COUNT, page: (params[:page] || 1))
  repos = collaborator.enterprise.owner_info.outside_collaborators.edges.first.repositories.nodes[pagy.offset, pagy.items]
  erb :collaborator, locals: { title: "#{login} Outside Collaborator - GitHub Explorer",
                               collaborator: collaborator,
                               two_factor_disabled: GITHUB.two_factor_disabled?(login),
                               repos: repos,
                               pagy: pagy }
end

get '/health?' do
  halt 200
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
  pagy = Pagy.new(count: count, items: USERS_ITEMS_COUNT, page: (params[:page] || 1))
  teams = FIRESTORE.members_teams[login_symbol].to_a[pagy.offset, pagy.items]
  erb :member, locals: { title: "#{login} Member - GitHub Explorer",
                         member: member,
                         owner: GITHUB.owner?(login),
                         two_factor_disabled: GITHUB.two_factor_disabled?(login),
                         teams: teams,
                         pagy: pagy }
end

get '/members/?' do
  begin
    all_members = GITHUB.all_members
  rescue GitHubError => e
    return erb :github_error, locals: { title: 'GitHub Explorer', message: e.message, type: e.type }
  end

  pagy = Pagy.new(count: all_members.count, items: ITEMS_COUNT, page: (params[:page] || 1))
  members = all_members[pagy.offset, pagy.items]
  erb :members, locals: { title: 'Members - GitHub Explorer',
                          members: members,
                          pagy: pagy }
end

get '/repositories/?' do
  all_repositories = FIRESTORE.all_repositories
  pagy = Pagy.new(count: all_repositories.count, items: ITEMS_COUNT, page: (params[:page] || 1))
  repositories = all_repositories[pagy.offset, pagy.items]
  erb :repositories, locals: { title: 'Repositories - GitHub Explorer',
                               repositories: repositories,
                               pagy: pagy }
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
                             repository_slug: repository_slug,
                             repo: repo,
                             access: access,
                             pagy: pagy }
end

get '/teams/?' do
  begin
    all_teams = GITHUB.all_teams
  rescue GitHubError => e
    return erb :github_error, locals: { title: 'GitHub Explorer', message: e.message, type: e.type }
  end

  pagy = Pagy.new(count: all_teams.count, items: ITEMS_COUNT, page: (params[:page] || 1))
  teams = all_teams[pagy.offset, pagy.items]
  erb :teams, locals: { title: 'Teams - GitHub Explorer',
                        teams: teams,
                        pagy: pagy }
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
                       team: team,
                       members: members,
                       pagy: pagy }
end

get '/two-factor-security/?' do
  begin
    two_factor_disabled_users = GITHUB.two_factor_disabled_users
  rescue GitHubError => e
    return erb :github_error, locals: { title: 'GitHub Explorer', message: e.message, type: e.type }
  end

  pagy = Pagy.new(count: two_factor_disabled_users.count, items: ITEMS_COUNT, page: (params[:page] || 1))
  users = two_factor_disabled_users[pagy.offset, pagy.items]
  erb :two_factor, locals: { title: '2FA Security - GitHub Explorer',
                             users: users,
                             pagy: pagy }
end

error do
  erb :error, locals: { title: '500 Internal Service Error - GitHub Explorer' }
end

not_found do
  erb :not_found, locals: { title: '404 Not Found - GitHub Explorer' }
end
