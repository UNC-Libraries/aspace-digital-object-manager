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

    def ==(other)
      other_jsonmodel =
        if other.is_a?(DigitalObject)
          DigitalObject.to_jsonmodel(other)
        elsif other.is_a?(JSONModel(:digital_object))
          other
        end
      if other_jsonmodel
        payload_jsonmodel_data.each do |k, v|
          if k == "file_versions"
            return false unless v.length == other_jsonmodel[k].length

            v.each.with_index do |file_version, i|
              file_version.each do |k2, v2|
                return false unless v2 == other_jsonmodel[k][i][k2]
              end
             end
          else
            return false unless other_jsonmodel[k] == v
          end
        end
        return true
      end

      super
    end

    def jsonmodel
      merge_jsonmodel_payload(bare_dig_obj_jsonmodel)
    end

    # Merge incoming payload data into base/existing jsonmodel data
    # For the file_versions array, merge each incoming file_version onto an existing
    # (or new, if needed) file_version, then remove any excess existing file_versions
    def merge_jsonmodel_payload(base_jsonmodel)
      json = base_jsonmodel.dup

      payload_jsonmodel_data.each do |k, v|
        if k == "file_versions"
          v.each.with_index do |file_version, i|
            json[k][i] ||= {}
            json[k][i].merge!(file_version)
          end
          json[k].slice!(v.length..-1) if json[k].length > v.length
        else 
          json[k] = v
        end
      end

      json
    end

    private

    def bare_dig_obj_jsonmodel
      JSONModel(:digital_object).new
    end

    # A hash that approximates a slice of Digital Object jsonmodel,
    # retaining only the elements we care about setting.
    #
    # Elements not included here we leave to Aspace to set/manage.
    # Only elements here are used in determining whether a ManagedDigitalObject
    # is equivalent to an ArchivesSpace::DigitalObject
    def payload_jsonmodel_data
      {
        "publish" => true,
        "title" => digital_object_title,
        "digital_object_id" => digital_object_id,
        "file_versions" => [
          {
            "jsonmodel_type" => "file_version",
            "file_uri" => uri,
            "use_statement" => role,
            "xlink_actuate_attribute" => "onRequest",
            "xlink_show_attribute" => "new",
            "publish" => true
          }
        ]
      }
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

    # Unescapes "\t" and "\\" into literal tab and backslash characters, which is required for the Aspace
    # title to include those literal characters. Other escape sequences, e.g. "\n" are not unescaped,
    # because it is not obvious including those literals in Aspace titles is desirable.
    def self.partially_unescape_title(title)
      return title unless title

      title.gsub(/\\([t\\])/) { $1 == 't' ? "\t" : "\\" }
    end
  end
end
