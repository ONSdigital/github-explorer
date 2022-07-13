# frozen_string_literal: true

require 'ons-firestore'

# Class to manage access to Firestore.
class FirestoreClient
  FIRESTORE_COLLECTION = 'github-explorer'

  def initialize(project)
    @firestore = Firestore.new(project)
  end

  def all_repositories
    @firestore.read_document(FIRESTORE_COLLECTION, 'all_repositories')
  end

  def all_users_contributions
    @firestore.read_document(FIRESTORE_COLLECTION, 'all_users_contributions')
  end

  def archived_repositories
    @firestore.read_document(FIRESTORE_COLLECTION, 'all_repositories').filter { |repo| repo[:isArchived] }
  end

  def archived_template_repositories_count
    archived_count = 0
    template_count = 0

    @firestore.read_document(FIRESTORE_COLLECTION, 'all_repositories').each do |repository|
      archived_count += 1 if repository[:isArchived]
      template_count += 1 if repository[:isTemplate]
    end

    [archived_count, template_count]
  end

  def inactive_six_months_users
    @firestore.read_document(FIRESTORE_COLLECTION, 'all_inactive_users_six_months')
  end

  def inactive_one_year_users
    @firestore.read_document(FIRESTORE_COLLECTION, 'all_inactive_users_one_year')
  end

  def inactive_two_years_users
    @firestore.read_document(FIRESTORE_COLLECTION, 'all_inactive_users_two_years')
  end

  def inactive_three_years_users
    @firestore.read_document(FIRESTORE_COLLECTION, 'all_inactive_users_three_years')
  end

  def members_teams
    @firestore.read_document(FIRESTORE_COLLECTION, 'all_members_teams')
  end

  def owner?(login)
    owners.each { |owner| return true if owner[:login].eql?(login) }
    false
  end

  def owners
    @firestore.read_document(FIRESTORE_COLLECTION, 'all_owners')
  end

  def private_repositories
    @firestore.read_document(FIRESTORE_COLLECTION, 'all_repositories').filter { |repo| repo[:isPrivate] }
  end

  def public_repositories
    @firestore.read_document(FIRESTORE_COLLECTION, 'all_repositories').filter do |repo|
      !repo[:isArchived] && !repo[:isPrivate] && !repo[:isTemplate]
    end
  end

  def teamless_members
    @firestore.read_document(FIRESTORE_COLLECTION, 'teamless_members')
  end

  def template_repositories
    @firestore.read_document(FIRESTORE_COLLECTION, 'all_repositories').filter { |repo| repo[:isTemplate] }
  end

  def two_factor_disabled
    @firestore.read_document(FIRESTORE_COLLECTION, 'all_two_factor_disabled')
  end

  def two_factor_disabled?(login)
    two_factor_disabled.each { |user_login| return true if user_login.eql?(login) }
    false
  end
end
