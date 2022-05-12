# frozen_string_literal: true

require 'ons-firestore'

# Class to manage access to Firestore.
class FirestoreClient
  FIRESTORE_COLLECTION = 'github-explorer'

  def initialize(project)
    @firestore = Firestore.new(project)
  end

  def all_inactive_users
    @firestore.read_document(FIRESTORE_COLLECTION, 'all_inactive_users')
  end

  def all_repositories
    @firestore.read_document(FIRESTORE_COLLECTION, 'all_repositories')
  end

  def all_users_contributions
    @firestore.read_document(FIRESTORE_COLLECTION, 'all_users_contributions')
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

  def teamless_members
    @firestore.read_document(FIRESTORE_COLLECTION, 'teamless_members')
  end

  def two_factor_disabled
    @firestore.read_document(FIRESTORE_COLLECTION, 'all_two_factor_disabled')
  end

  def two_factor_disabled?(login)
    two_factor_disabled.each { |user_login| return true if user_login.eql?(login) }
    false
  end
end
