# frozen_string_literal: true

module ArchivesSpace
  class CdmDigitalObject < ManagedDigitalObject
    attr_reader :collection_number, :aspace_container_type, :ao_title,
                :hook_id, :container_indicator

    # - content_id is a cache_hookid, e.g. "01234_folder_1"
    # - collection number needs to include any z modifiers (e.g. "01234-z") or
    #     the CDM search links will fail. The `collid` field from the mapping
    #     file includes z-modifiers. But, for example, the collection number
    #     used as acache_hookid prefix does not, and so would not work.
    # - aspace_container_type (e.g. "folder", "openreelvideo") should be taken
    #     from an aspace_hookid. cache_hookid container types are based on EAD
    #     container types, which will sometimes differ
    # - ao_title is the title of any one AO that is or will be linked to this DO
    def initialize(content_id:, collection_number:, aspace_container_type:, ao_title:, **_kwargs)
      @content_id = content_id
      @collection_number = collection_number
      @aspace_container_type = aspace_container_type
      @ao_title = ao_title

      @hook_id = @content_id.split('_', 2).last
      @container_indicator = @hook_id.split('_', 2).last
    end

    def self.digital_object_id(collection_number:, hook_id: nil, content_id: nil)
      return unless hook_id || content_id

      hook_id ||= content_id.split('_', 2).last
      "cdm:#{collection_number}_#{hook_id}"
    end

    private

    def digital_object_id
      self.class.digital_object_id(collection_number: collection_number, hook_id: hook_id)
    end

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

    def self.container_label(type:)
      label = container_map[type]
      return label if label

      raise StandardError, "CdmDigitalObject encountered an unmapped aspace container type: #{type}"
    end

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
