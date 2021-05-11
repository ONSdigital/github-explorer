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
    puts data
    document = @client.col(FIRESTORE_COLLECTION).doc(name)
    hash_data = data.map(&:to_h) if data.is_a?(Array)

    if data.is_a?(Hash)
      hash_data = {}
      data.each do |key, value|
        hash_data[key] = value.map(&:to_h)
      end
    end

    begin
      document.set({ data: hash_data, updated: Time.now.strftime(DATE_TIME_FORMAT) })
    rescue StandardError => e
      @logger.error("Failed to save Firestore document #{name} in collection #{FIRESTORE_COLLECTION}: #{e.message}")
      @logger.error(e.backtrace.join("\n"))
    end
  end
end
