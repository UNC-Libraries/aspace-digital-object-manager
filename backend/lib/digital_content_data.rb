# frozen_string_literal: true

require_relative 'cdm_digital_object'
require_relative 'dcr_digital_object'

module ArchivesSpace
  # Stores input metadata for each unit of digital content (correspoonding
  # to a Digital Object), sufficient to create a DO jsonmodel and link it to
  # a specific AO
  class DigitalContentData
    attr_reader :source, :content_id, :ref_id,
                :content_title,
                :collection_number, :aspace_hookid, :cdm_alias, :ao_title,
                :validated

    def initialize(args = {})
      @source = args[:source]
      @content_id = args[:content_id]
      @ref_id = args[:ref_id]

      @content_title = args[:content_title]

      @collection_number = args[:collection_number]
      @aspace_hookid = args[:aspace_hookid]
      @cdm_alias = args[:cdm_alias]
      @ao_title = args[:ao_title]
    end

    # Returns DO Model corresponding to the metadata source
    def digital_object_model
      case source
      when 'dcr'
        DcrDigitalObject
      when 'cdm'
        CdmDigitalObject
      else
        raise StandardError, "Unrecognized source: #{source}"
      end
    end

    # Validates input data
    def validate
      digital_object_model.validate(self)
      @validated = true
    end

    # Returns a ManagedDigitalObject (or subclass) based on this input data
    def digital_object(**kwargs)
      @digital_object ||= digital_object_model.new(self, **kwargs)
    end

    # Direct, quick access to the digital_object_id allows us to check
    # whether we need a Digital Object in Aspace and avoid creating a
    # FooDigitalObject when we do not.
    def digital_object_id
      @digital_object_id ||= digital_object_model.id_from_data(self)
    end
  end
end
