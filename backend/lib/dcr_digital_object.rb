# frozen_string_literal: true
require_relative 'managed_digital_object'

module ArchivesSpace
  class DcrDigitalObject < ManagedDigitalObject
    attr_reader :content_title

    def initialize(content_id:, content_title:, **_kwargs)
      @content_id = content_id
      @content_title = content_title
    end

    private

    def digital_object_id
      "dcr:#{content_id}"
    end

    def digital_object_title
      content_title
    end

    def uri
      "https://dcr.lib.unc.edu/record/#{content_id}"
    end
  end
end
