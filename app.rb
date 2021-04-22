# frozen_string_literal: true

require 'sinatra'
require 'sinatra/partial'
require 'pagy'

require_relative 'lib/configuration'
require_relative 'lib/github'
require_relative 'lib/github_error'

set :partial_template_engine, :erb

include Pagy::Backend
Pagy::I18n.load(locale: 'en', filepath: 'locales/en.yml')

config = Configuration.new(ENV)
set :github_api_base_uri, config.github_api_base_uri
set :github_enterprise,   config.github_enterprise
set :github_organisation, config.github_organisation
set :github_token,        config.github_token

GITHUB = GitHub.new(settings.github_api_base_uri, settings.github_token)
ITEMS_COUNT         = 40
MEMBERS_ITEMS_COUNT = 10

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
  user_header = request.env['HTTP_X_GOOG_AUTHENTICATED_USER_EMAIL']
  @user = user_header.partition('accounts.google.com:').last unless user_header.nil?
end

get '/?' do
  begin
    GITHUB.perform_team_membership_lookup(settings.github_organisation)
    GITHUB.perform_member_role_lookup(settings.github_organisation)
    data = GITHUB.summary(settings.github_enterprise, settings.github_organisation).data
  rescue GitHubError => e
    return erb :error, locals: { title: 'GitHub Explorer', message: e.message, type: e.type }
  end

  pagy = Pagy.new(count: GITHUB.owners.count, page: (params[:page] || 1))
  owners = GITHUB.owners.sort_by(&:login)[pagy.offset, pagy.items]
  erb :index, locals: { title: "#{settings.github_organisation} - GitHub Explorer", data: data,
                        owners: owners, pagy: pagy }
end

get '/health?' do
  halt 200
end

get '/members/:login' do |login|
  begin
    data = GITHUB.member(settings.github_enterprise, login).data
  rescue GitHubError => e
    return erb :error, locals: { title: 'GitHub Explorer', message: e.message, type: e.type }
  end

  count = GITHUB.members_teams[login].nil? ? 0 : GITHUB.members_teams[login].count
  pagy = Pagy.new(count: count, items: MEMBERS_ITEMS_COUNT, page: (params[:page] || 1))
  teams = GITHUB.members_teams[login].to_a[pagy.offset, pagy.items]
  erb :member, locals: { title: "#{login} - GitHub Explorer", data: data,
                         owner: GITHUB.owner?(login), teams: teams, pagy: pagy }
end

get '/members/?' do
  begin
    all_members = GITHUB.all_members(settings.github_enterprise)
  rescue GitHubError => e
    return erb :error, locals: { title: 'GitHub Explorer', message: e.message, type: e.type }
  end

  pagy = Pagy.new(count: all_members.count, items: ITEMS_COUNT, page: (params[:page] || 1))
  members = all_members[pagy.offset, pagy.items]
  erb :members, locals: { title: 'Members - GitHub Explorer', members: members, pagy: pagy }
end

get '/teams/?' do
  begin
    all_teams = GITHUB.all_teams(settings.github_organisation)
  rescue GitHubError => e
    return erb :error, locals: { title: 'GitHub Explorer', message: e.message, type: e.type }
  end

  pagy = Pagy.new(count: all_teams.count, items: ITEMS_COUNT, page: (params[:page] || 1))
  teams = all_teams[pagy.offset, pagy.items]
  erb :teams, locals: { title: 'Teams - GitHub Explorer', teams: teams, pagy: pagy }
end
