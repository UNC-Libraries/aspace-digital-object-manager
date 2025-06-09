# frozen_string_literal: true

require_relative 'managed_digital_object'

module ArchivesSpace
  class CdmDigitalObject < ManagedDigitalObject
    attr_reader :collection_number, :cdm_alias, :ao_title

    # - content_id is a cache_hookid, e.g. "01234_folder_1"
    # - collection_number needs to include any z modifiers (e.g. "01234-z") or
    #     the CDM search links will fail. The `collid` field from the mapping
    #     file includes z-modifiers. But, for example, the collection number
    #     used as acache_hookid prefix does not, and so would not work.
    # - aspace_hookid is used to extract an Aspace container type (e.g. "folder",
    #     "openreelvideo"). It's important to use an aspace_hookid, not a
    #     cache_hookid, because aspace container types sometimes differ from
    #     cache/EAD container types
    # - cdm_alias is effectively the number/alias for the *CDM* collection,
    #     which for content in "bucket" CDM collections will differ from the
    #     collection_number (i.e. the *EAD* collection number)
    # - ao_title is the title of any one AO that is or will be linked to this DO
    def initialize(content_data, skip_validation: false, **kwargs)
      content_data.validate unless skip_validation || content_data.validated

      @content_id = content_data.content_id
      @collection_number = content_data.collection_number
      @aspace_hookid = content_data.aspace_hookid
      @cdm_alias = content_data.cdm_alias

      @ao_title = content_data.ao_title
    end

    def aspace_container_type
      @aspace_container_type ||= @aspace_hookid.split('_').at(1)
    end

    def hook_id
      @hook_id ||= content_id.split('_', 2).last
    end

    def container_indicator
      @container_indicator ||= hook_id.split('_', 2).last
    end

    def self.id_from_data(input_data)
      hook_id = input_data.content_id&.split('_', 2)&.last

      "cdm:#{input_data.collection_number}_#{hook_id}"
    end

    def self.validate(input_data)
      unless input_data.ref_id&.match?(/^\h{32}$/)
        raise ValidationError, "Invalid ref_id: #{input_data.ref_id}"
      end

      unless input_data.content_id&.match?(/^[^_]+_[^_]+_.*$/)
        raise ValidationError, "Invalid content_id: #{input_data.content_id}"
      end

      unless input_data.collection_number&.match?(/^[a-zA-Z0-9-]+$/)
        raise ValidationError, "Invalid collection_number: #{input_data.collection_number}"
      end

      unless input_data.aspace_hookid&.match?(/^[^_]+_[^_]+_.*$/)
        raise ValidationError, "Invalid aspace_hookid: #{input_data.aspace_hookid}"
      end

      if input_data.cdm_alias.to_s.empty?
        raise ValidationError, "Invalid cdm_alias: #{input_data.cdm_alias}"
      end

      true
    end

    private

    def digital_object_id
      "cdm:#{collection_number}_#{hook_id}"
    end

    def digital_object_title
      unescaped_ao_title = self.class.partially_unescape_title(ao_title)
      "#{container_label} #{container_indicator}: #{unescaped_ao_title}"
    end

    def container_label
      self.class.container_label(type: aspace_container_type)
    end

    # Note: the "/order/relatid" parameter does not function without the
    #   "/collection/#{cdm_alias}"" scoping (AS-754)
    def uri
      'https://dc.lib.unc.edu/cdm/search' \
      "/collection/#{cdm_alias}/searchterm/" \
      "#{hook_id}!#{collection_number}" \
      '/field/all!all/mode/exact!exact/conn/and!and' \
      '/order/relatid'
    end

    def role
      # All DO URLs to CDM are links to CDM search results - CDM role will
      # always be 'link' regardless of content type
      'link'
    end

    def self.container_label(type:)
      label = container_map[type]
      return label if label

      raise ContainerMappingError, "CdmDigitalObject could not find an Aspace match for container type: #{type}"
    end
    class ContainerMappingError < RuntimeError; end

    def self.aspace_container_types
      EnumerationValue.where(
        enumeration_id: Enumeration.first(name: 'container_type').id
      ).map(:value)
    end

    def self.container_map
      @new_container_map ||= refresh_container_map
    end

    # Generates a hash mapping normalized Aspace container types to
    # the unnormalized, e.g. { 'imagefolder' => 'Image Folder' ...}
    #
    # The container types are read from Aspace and normalized using
    # the same normalization we use in producing the hookid:refid
    # maps used to submit CDM data to DOMino.
    #
    # We override a few of the Aspace container types when the
    # unnormalized Aspace value is not our preferred casing.
    def self.refresh_container_map
      @new_container_map = aspace_container_types.map { |type|
        [type.downcase.gsub(/[ ()-]/, ''), type]
      }.to_h.
        merge(container_mapping_overrides)
    end

    # We override some Aspace mappings to have a preferred casing.
    # In general we would rather they be fixed in Aspace, but it's
    # possible 'box' and 'folder' are populated in off-the-shelf
    # Aspace, and for 'folder' we have 350k containers and may not
    # want to merge/correct them.
    def self.container_mapping_overrides
      {
        'box' => 'Box',
        'folder' => 'Folder',
        'volume' => 'Volume'
      }
    end
  end
end
