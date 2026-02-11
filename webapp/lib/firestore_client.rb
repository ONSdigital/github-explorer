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

  def all_inactive_users_updated
    @firestore.document_updated("#{FIRESTORE_COLLECTION}-#{@organisation}", 'all_inactive_users')
  end

  def all_members
    @firestore.read_document("#{FIRESTORE_COLLECTION}-#{@organisation}", 'all_members')
  end

  def all_members_updated
    @firestore.document_updated("#{FIRESTORE_COLLECTION}-#{@organisation}", 'all_members')
  end

  def all_members_teams
    @firestore.read_document("#{FIRESTORE_COLLECTION}-#{@organisation}", 'all_members_teams')
  end

  def all_members_teams_updated
    @firestore.document_updated("#{FIRESTORE_COLLECTION}-#{@organisation}", 'all_members_teams')
  end

  def all_organisation_members
    organisation_members = []
    members = @firestore.read_document("#{FIRESTORE_COLLECTION}-#{@organisation}", 'all_members')

    members.each do |member|
      member[:organisations].each do |organisation|
        if organisation.eql?(@organisation)
          organisation_members << member
          break
        end
      end
    end

    organisation_members
  end

  def all_owners
    @firestore.read_document("#{FIRESTORE_COLLECTION}-#{@organisation}", 'all_owners')
  end

  def all_owners_updated
    @firestore.document_updated("#{FIRESTORE_COLLECTION}-#{@organisation}", 'all_owners')
  end

  def all_repositories
    read_chunked_document('all_repositories')
  end

  def all_repositories_updated
    @firestore.document_updated("#{FIRESTORE_COLLECTION}-#{@organisation}", 'all_repositories')
  end

  def all_two_factor_disabled
    @firestore.read_document("#{FIRESTORE_COLLECTION}-#{@organisation}", 'all_two_factor_disabled')
  end

  def all_two_factor_disabled_updated
    @firestore.document_updated("#{FIRESTORE_COLLECTION}-#{@organisation}", 'all_two_factor_disabled')
  end

  def all_users_contributions
    @firestore.read_document("#{FIRESTORE_COLLECTION}-#{@organisation}", 'all_users_contributions')
  end

  def all_users_contributions_updated
    @firestore.document_updated("#{FIRESTORE_COLLECTION}-#{@organisation}", 'all_users_contributions')
  end

  def archived_repositories
    read_chunked_document('all_repositories').filter { |repo| repo[:isArchived] }
  end

  def archived_template_repositories_count
    archived_count = 0
    template_count = 0

    read_chunked_document('all_repositories').each do |repository|
      archived_count += 1 if repository[:isArchived]
      template_count += 1 if repository[:isTemplate]
    end

    [archived_count, template_count]
  end

  def owner?(login)
    all_owners.each { |owner| return true if owner[:login].eql?(login) }
    false
  end

  def private_repositories
    read_chunked_document('all_repositories').filter { |repo| repo[:isPrivate] }
  end

  def public_repositories
    read_chunked_document('all_repositories').filter do |repo|
      !repo[:isArchived] && !repo[:isPrivate] && !repo[:isTemplate]
    end
  end

  def teamless_members
    @firestore.read_document("#{FIRESTORE_COLLECTION}-#{@organisation}", 'teamless_members')
  end

  def teamless_members_updated
    @firestore.document_updated("#{FIRESTORE_COLLECTION}-#{@organisation}", 'teamless_members')
  end

  def template_repositories
    read_chunked_document('all_repositories').filter { |repo| repo[:isTemplate] }
  end

  def two_factor_disabled?(login)
    all_two_factor_disabled.each { |user_login| return true if user_login.eql?(login) }
    false
  end

  def user_contributions(login)
    all_users_contributions.filter { |user| user[:login].eql?(login) }
  end

  private

  def read_chunked_document(document_name)
    @chunked_cache ||= {}
    return @chunked_cache[document_name] if @chunked_cache.key?(document_name)

    data = @firestore.read_document("#{FIRESTORE_COLLECTION}-#{@organisation}", document_name)

    @chunked_cache[document_name] = if data.is_a?(Hash) && (data.key?(:chunk_count) || data.key?('chunk_count'))
                                      reassemble_chunks(document_name, data)
                                    else
                                      data
                                    end
  end

  def reassemble_chunks(document_name, meta)
    chunk_count = meta[:chunk_count] || meta['chunk_count']
    all_data = []

    chunk_count.times do |i|
      chunk = @firestore.read_document("#{FIRESTORE_COLLECTION}-#{@organisation}",
                                       "#{document_name}_chunk_#{i}")
      all_data.concat(chunk)
    end

    all_data
  end
end
