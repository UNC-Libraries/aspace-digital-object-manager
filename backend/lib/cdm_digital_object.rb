# frozen_string_literal: true

require_relative 'managed_digital_object'

module ArchivesSpace
  class CdmDigitalObject < ManagedDigitalObject
    attr_reader :collection_number, :ao_title

    # - content_id is a cache_hookid, e.g. "01234_folder_1"
    # - collection number needs to include any z modifiers (e.g. "01234-z") or
    #     the CDM search links will fail. The `collid` field from the mapping
    #     file includes z-modifiers. But, for example, the collection number
    #     used as acache_hookid prefix does not, and so would not work.
    # - aspace_hookid is used to extract an Aspace container type (e.g. "folder",
    #     "openreelvideo"). It's important to use an aspace_hookid, not a
    #     cache_hookid, because aspace container types sometimes differ from
    #     cache/EAD container types
    # - ao_title is the title of any one AO that is or will be linked to this DO
    def initialize(content_data, skip_validation: false, **kwargs)
      content_data.validate unless skip_validation || content_data.validated

      @content_id = content_data.content_id
      @collection_number = content_data.collection_number
      @aspace_hookid = content_data.aspace_hookid

      @ao_title = kwargs[:ao_title]
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
      unless input_data.ref_id.match?(/^\h{32}$/)
        raise ValidationError, "Invalid ref_id: #{input_data.ref_id}"
      end

      unless input_data.content_id.match?(/^[^_]+_[^_]+_.*$/)
        raise ValidationError, "Invalid content_id: #{input_data.content_id}"
      end

      unless input_data.collection_number.match?(/^[a-zA-Z0-9-]+$/)
        raise ValidationError, "Invalid collection_number: #{input_data.collection_number}"
      end

      unless input_data.aspace_hookid.match?(/^[^_]+_[^_]+_.*$/)
        raise ValidationError, "Invalid aspace_hookid: #{input_data.aspace_hookid}"
      end

      true
    end

    private

    def digital_object_id
      "cdm:#{collection_number}_#{hook_id}"
    end

    def digital_object_title
      "#{container_label} #{container_indicator}: #{ao_title}"
    end

    def container_label
      self.class.container_label(type: aspace_container_type)
    end

    def uri
      'https://dc.lib.unc.edu/cdm/search/searchterm/' \
      "#{hook_id}!#{collection_number}" \
      '/field/all!all/mode/exact!exact/conn/and!and'
    end

    def role
      # All DO URLs to CDM are links to CDM search results - CDM role will
      # always be 'link' regardless of content type
      'link'
    end

    def self.container_label(type:)
      label = container_map[type]
      return label if label

      raise ContainerMappingError, "CdmDigitalObject encountered an unmapped aspace container type: #{type}"
    end
    class ContainerMappingError < RuntimeError; end

    # Maps *Aspace* container types to Aspace container labels
    def self.container_map
      {
        'audiocassette' => 'Audiocassette',
        'audiodisc' => 'Audio Disc',
        'audiotape' => 'Audiotape',
        'bw0810print' => 'Black and White 8x10 Photographic Print',
        'bw120rollfilm' => 'Black and White 120 Roll Film',
        'bw35rollfilm' => 'Black and White 35mm Roll Film',
        'bwfilmbox' => 'Black and White Film Box',
        'bwpprint' => 'Black and White Photographic Print',
        'bwsheetfilm' => 'Black and White Sheet Film',
        'c120rollfilm' => 'Color 120 Roll Film',
        'c35rollfilm' => 'Color 35mm Roll Film',
        'c35slide' => 'Color 35mm Slide',
        'cpprint' => 'Color Photographic Print',
        'csheetfilm' => 'Color Sheet Film',
        'cylinder' => 'Cylinder',
        'digitalaudiotape' => 'Digital Audiotape',
        'documentcase' => 'Document Case',
        'envelope' => 'Envelope',
        'extraoversizepaper' => 'Extra Oversize Paper',
        'extraoversizepaperfolder' => 'Extra Oversize Paper Folder',
        'film' => 'Film',
        'flatbox' => 'Flat Box',
        'folder' => 'Folder',
        'image' => 'Image',
        'imagebox' => 'Image Box',
        'imagefolder' => 'Image Folder',
        'instantaneousdisc' => 'Instantaneous Disc',
        'item' => 'Item',
        'microfilmpositivereel' => 'Microfilm (positive Reel)',
        'minidisc' => 'Minidisc',
        'museumitem' => 'Museum Item',
        'oimage' => 'Oversize Image',
        'openreelvideo' => 'Open Reel Video',
        'oversizeimage' => 'Oversize Image',
        'oversizeimagefolder' => 'Oversize Image Folder',
        'oversizepaper' => 'Oversize Paper',
        'oversizepaperfolder' => 'Oversize Paper Folder',
        'oversizevolume' => 'Oversize Volume',
        'photoalbum' => 'Photograph Album',
        'photographalbum' => 'Photograph Album',
        'pprint' => 'Photographic Print',
        'recordcarton' => 'Record Carton',
        'rolleditem' => 'Rolled Item',
        'separatedfolder' => 'Separated Folder',
        'sfcaudiocassette' => 'SFC Audiocassette',
        'sfcaudioopenreel' => 'SFC Audio Open Reel',
        'sfimage' => 'Special Format Image',
        'sheetfilm' => 'Sheet Film',
        'slide' => 'Slide',
        'specialformatimage' => 'Special Format Image',
        'svvolume' => 'SV Volume',
        'track' => 'Track',
        'transcriptiondisc' => 'Transcription Disc',
        'transcriptionvolume' => 'Transcription Volume',
        'videotape' => 'Videotape',
        'volume' => 'Volume',
        'wirerecording' => 'Wire Recording',
      }
    end
  end
end
