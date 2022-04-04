# frozen_string_literal: true

# Class representing a GitHub user's login and name.
class UserSummary
    attr_reader :login,
                :name
  
    def initialize(login, name)
      @login = login
      @name  = name
    end
  
    def to_h
      { login: @login, name: @name }
    end
  end
  