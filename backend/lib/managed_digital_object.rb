# frozen_string_literal: true

module ArchivesSpace

  # Template class for managed Digital Objects in Aspace. You should instead
  # instantiate a DcrDigitalObject or CdmDigitalObject. You can automatically
  # instantiate the correct subclass with DigitalContentData#digital_object
  class ManagedDigitalObject
    attr_reader :content_id

    def initialize(_content_data, **_kwargs)
      raise NoMethodError, "Use `ManagedDigitalObject.from_data` or instantiate a subclass directly"
    end

    def jsonmodel
      model = bare_dig_obj_jsonmodel

      model["publish"] = true
      model["title"] = digital_object_title
      model["digital_object_id"] = digital_object_id
      model["file_versions"] = [
        {
          "jsonmodel_type" => "file_version",
          "file_uri" => uri,
          "use_statement" => role,
          "xlink_actuate_attribute" => "onRequest",
          "xlink_show_attribute" => "new",
          "publish" => true
      }
      ]
      model
    end

    private

    def bare_dig_obj_jsonmodel
      JSONModel(:digital_object).new
    end

    def digital_object_id
      raise NoMethodError, "#{self.class} must implement #digital_object_id"
    end

    def digital_object_title
      raise NoMethodError, "#{self.class} must implement #digital_object_title"
    end

    def uri
      raise NoMethodError, "#{self.class} must implement #content_id_to_uri"
    end

    # Aspace 'Use Statement" field
    def role
      raise NoMethodError, "#{self.class} must implement #role"
    end

    def self.validate
      raise NoMethodError, "#{self.class} must implement .validate"
    end
    class ValidationError < RuntimeError; end
  end
end
