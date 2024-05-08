# frozen_string_literal: true

module ArchivesSpace

  # Template class for managed Digital Objects in Aspace. You should instead
  # instantiate a DcrDigitalObject or CdmDigitalObject. You can automatically
  # instantiate the correct subclass with ManagedDigitalObject.from_data
  class ManagedDigitalObject
    attr_reader :content_id

    def initialize(**_kwargs)
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

    def self.from_data(**kwargs)
      content_id = kwargs[:content_id]
      case content_id
      when /^\h{8}\-\h{4}\-\h{4}\-\h{4}\-\h{12}$/ # Work UUID
        DcrDigitalObject.new(**kwargs)
      when /^[^_]+_[^_]+_.*$/ # hookID with collection prefix, e.g. "01234_folder_1"
        CdmDigitalObject.new(**kwargs)
      else
        raise StandardError, "Invalid content_id format: #{content_id}"
      end
    end
  end
end
