# frozen_string_literal: true

require 'google/cloud/firestore'

# Class to manage access to Firestore.
class Firestore
  DATE_TIME_FORMAT     = '%A %d %b %Y %H:%M:%S UTC'
  FIRESTORE_COLLECTION = 'github-explorer'

  def initialize(project, logger)
    Google::Cloud::Firestore.configure { |config| config.project_id = project }
    @client = Google::Cloud::Firestore.new
    @logger = logger
  end

  def save_document(name, data)
    document = @client.col(FIRESTORE_COLLECTION).doc(name)
    wrapper = data.map(&:to_h) if data.is_a?(Array)

    begin
      document.set({ data: wrapper, updated: Time.now.strftime(DATE_TIME_FORMAT) })
    rescue StandardError => e
      @logger.error("Failed to save Firestore document #{name} in collection #{FIRESTORE_COLLECTION}: #{e.message}")
      @logger.error(e.backtrace.join("\n"))
    end
  end
end
