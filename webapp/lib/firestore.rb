# frozen_string_literal: true

require 'google/cloud/firestore'

# Class to manage access to Firestore.
class Firestore
  FIRESTORE_COLLECTION = 'github-explorer'

  def initialize(project)
    Google::Cloud::Firestore.configure { |config| config.project_id = project }
    @client = Google::Cloud::Firestore.new
  end

  def all_repositories
    read_document('all_repositories')
  end

  def members_teams
    @members_teams ||= read_document('all_members_teams')
  end

  def owner?(login)
    owners.each { |owner| return true if owner[:login].eql?(login) }
    false
  end

  def owners
    @owners ||= read_document('all_owners')
  end

  def two_factor_disabled
    @two_factor_disabled ||= read_document('all_two_factor_disabled')
  end

  def two_factor_disabled?(login)
    two_factor_disabled.each { |user_login| return true if user_login.eql?(login) }
    false
  end

  private

  def read_document(name)
    document = @client.col(FIRESTORE_COLLECTION).doc(name)
    snapshot = document.get
    snapshot[:data]
  end
end
