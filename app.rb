# frozen_string_literal: true

require 'sinatra'
require 'sinatra/partial'

require_relative 'lib/configuration'
require_relative 'lib/github'

set :partial_template_engine, :erb

config = Configuration.new(ENV)
set :github_api_base_uri, config.github_api_base_uri
set :github_enterprise,   config.github_enterprise
set :github_organisation, config.github_organisation
set :github_token,        config.github_token

GITHUB = GitHub.new(settings.github_api_base_uri, settings.github_token)

helpers do
  def d(text)
    Time.parse(text).utc.strftime('%d/%m/%Y %H:%M')
  end

  def h(text)
    Rack::Utils.escape_html(text)
  end

  def pluralise(count, singular_noun)
    count == 1 ? "#{count} #{singular_noun}" : "#{count} #{singular_noun}s"
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
#   @user = user_header.partition('accounts.google.com:').last unless user_header.nil?
  @user = 'john.topley@census.gov.uk'
end

get '/?' do
  GITHUB.perform_team_membership_lookup(settings.github_organisation)
  data = GITHUB.summary(settings.github_enterprise, settings.github_organisation).data
  erb :index, locals: { title: "#{settings.github_organisation} - GitHub Explorer", data: data }
end

get '/health?' do
  halt 200
end

get '/members/:login' do |login|
  data = GITHUB.member(settings.github_enterprise, login).data
  erb :member, locals: { title: "#{login} - GitHub Explorer", data: data, teams: GITHUB.members_teams[login] }
end

get '/members/?' do
  first  = params[:f]
  last   = params[:l]
  before = params[:b]
  after  = params[:a]  
  data = GITHUB.all_members(settings.github_enterprise, first, last, before, after).data
  erb :members, locals: { title: 'Members - GitHub Explorer', data: data }
end

get '/teams/?' do
  first  = params[:f]
  last   = params[:l]
  before = params[:b]
  after  = params[:a]
  data = GITHUB.all_teams(settings.github_organisation, first, last, before, after).data
  erb :teams, locals: { title: 'Teams - GitHub Explorer', data: data }
end
