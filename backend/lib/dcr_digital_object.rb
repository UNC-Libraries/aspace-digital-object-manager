# frozen_string_literal: true

require_relative 'managed_digital_object'

module ArchivesSpace
  class DcrDigitalObject < ManagedDigitalObject
    attr_reader :content_title

    def initialize(content_data, skip_validation: false, **kwargs)
      content_data.validate unless skip_validation || content_data.validated

      @content_id = content_data.content_id
      @content_title = content_data.content_title
    end

    def self.id_from_data(input_data)
      "dcr:#{input_data.content_id}"
    end

    def self.validate(input_data)
      unless input_data.ref_id.match?(/^\h{32}$/)
        raise ValidationError, "Invalid ref_id: #{input_data.ref_id}"
      end

      unless input_data.content_id.match?(/^\h{8}\-\h{4}\-\h{4}\-\h{4}\-\h{12}$/)
        raise ValidationError, "Invalid content_id: #{input_data.content_id}"
      end

      unless input_data.content_title.match?(/^[[:print:]]+$/)
        raise ValidationError, "Invalid content_title: #{input_data.content_title}"
      end
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

    def role
      # DCR DOs should have more specific-roles when possible, but until
      # we have means of assigning them, we use only the default 'link'
      'link'
    end
  end
end
