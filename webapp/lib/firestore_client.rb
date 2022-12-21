# frozen_string_literal: true

require 'ons-firestore'

# Class to manage access to Firestore.
class FirestoreClient
  FIRESTORE_COLLECTION = 'github-explorer'

  def initialize(project, organisation)
    @firestore    = Firestore.new(project)
    @organisation = organisation
  end

  def all_inactive_users
    @firestore.read_document("#{FIRESTORE_COLLECTION}-#{@organisation}", 'all_inactive_users')
  end

  def all_members
    @firestore.read_document("#{FIRESTORE_COLLECTION}-#{@organisation}", 'all_members')
  end

  def all_organisation_members
    organisation_members = []
    members = @firestore.read_document("#{FIRESTORE_COLLECTION}-#{@organisation}", 'all_members')

    members.each do |member|
      member.organisations.each do |organisation|
        if organisation.eql?(@organisation)
          organisation_members << member
          break
        end
      end
    end

    organisation_members
  end

  def all_repositories
    @firestore.read_document("#{FIRESTORE_COLLECTION}-#{@organisation}", 'all_repositories')
  end

  def all_users_contributions
    @firestore.read_document("#{FIRESTORE_COLLECTION}-#{@organisation}", 'all_users_contributions')
  end

  def archived_repositories
    @firestore.read_document("#{FIRESTORE_COLLECTION}-#{@organisation}",
                             'all_repositories').filter { |repo| repo[:isArchived] }
  end

  def archived_template_repositories_count
    archived_count = 0
    template_count = 0

    @firestore.read_document("#{FIRESTORE_COLLECTION}-#{@organisation}", 'all_repositories').each do |repository|
      archived_count += 1 if repository[:isArchived]
      template_count += 1 if repository[:isTemplate]
    end

    [archived_count, template_count]
  end

  def members_teams
    @firestore.read_document("#{FIRESTORE_COLLECTION}-#{@organisation}", 'all_members_teams')
  end

  def owner?(login)
    owners.each { |owner| return true if owner[:login].eql?(login) }
    false
  end

  def owners
    @firestore.read_document("#{FIRESTORE_COLLECTION}-#{@organisation}", 'all_owners')
  end

  def private_repositories
    @firestore.read_document("#{FIRESTORE_COLLECTION}-#{@organisation}",
                             'all_repositories').filter { |repo| repo[:isPrivate] }
  end

  def public_repositories
    @firestore.read_document("#{FIRESTORE_COLLECTION}-#{@organisation}", 'all_repositories').filter do |repo|
      !repo[:isArchived] && !repo[:isPrivate] && !repo[:isTemplate]
    end
  end

  def teamless_members
    @firestore.read_document("#{FIRESTORE_COLLECTION}-#{@organisation}", 'teamless_members')
  end

  def template_repositories
    @firestore.read_document("#{FIRESTORE_COLLECTION}-#{@organisation}",
                             'all_repositories').filter { |repo| repo[:isTemplate] }
  end

  def two_factor_disabled
    @firestore.read_document("#{FIRESTORE_COLLECTION}-#{@organisation}", 'all_two_factor_disabled')
  end

  def two_factor_disabled?(login)
    two_factor_disabled.each { |user_login| return true if user_login.eql?(login) }
    false
  end
end
