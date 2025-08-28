# frozen_string_literal: true

require_relative 'managed_digital_object'

module ArchivesSpace
  class DcrDigitalObject < ManagedDigitalObject
    attr_reader :content_title, :content_type

    def initialize(content_data, skip_validation: false, **kwargs)
      content_data.validate unless skip_validation || content_data.validated

      @content_id = content_data.content_id
      @content_title = content_data.content_title
      @content_type = content_data.content_type&.downcase || 'link'
    end

    def self.id_from_data(input_data)
      "dcr:#{input_data.content_id}"
    end

    def self.validate(input_data)
      unless input_data.ref_id&.match?(/^\h{32}$/)
        raise ValidationError, "Invalid ref_id: #{input_data.ref_id}"
      end

      unless input_data.content_id&.match?(/^\h{8}\-\h{4}\-\h{4}\-\h{4}\-\h{12}$/)
        raise ValidationError, "Invalid content_id: #{input_data.content_id}"
      end

      unless input_data.content_title&.match?(/^[[:print:]\t]+$/)
        raise ValidationError, "Invalid content_title: #{input_data.content_title}"
      end

      # when no content_type is provided we use a default value
      unless valid_roles.include?(input_data.content_type&.downcase) || !input_data.content_type
        raise ValidationError, "Invalid content_type: #{input_data.content_type}"
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
      content_type
    end

    def self.valid_roles
      @valid_roles ||= [
        'link', 'image', 'pdf', 'audio', 'video', 'streaming audio',
        'streaming video'
      ]
    end
  end
end
