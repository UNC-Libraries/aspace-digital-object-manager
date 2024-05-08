# frozen_string_literal: true
require 'json'

module ArchivesSpace
  class DigitalObjectManager
    attr_reader :source, :repo_id

    def initialize(source:, repo_id:)
      @source = source
      @repo_id = repo_id

      # We include `@source` in some of the SQL queries, so this also
      # serves to sanitize those values through an allow list
      unless [cdm_source, dcr_source].include?(source)
        raise StandardError, "Source must be either '#{dcr_source}' or '#{cdm_source}'"
      end
    end

    def handle_datafile(datafile, deletion_scope: nil)
      CSV.foreach(datafile, headers: true) do |row|
        # universal
        content_id = row['content_id'] || row['uuid'] || row['cache_hookid']
        ref_id = row['ref_id']
        # dcr
        content_title = row['content_title'] || row['work_title']
        # cdm
        collection_number = row['collid']
        aspace_container_type = row['aspace_hookid']&.split('_')&.at(1)

        # We store all of the seen content_id:ref_id pairs in upload_inventory
        # so that we can later retrieve all of the Aspace AO/DO pairs and delete
        # from Aspace any links that are no longer valid (and that fall within
        # the deletion_scope)
        digital_object_id = "#{source}:#{content_id}"
        upload_inventory[digital_object_id] ||= []
        upload_inventory[digital_object_id] << ref_id
        next unless digital_object_needed?(digital_object_id, ref_id)

        archival_object = ArchivalObject.find(ref_id: ref_id)
        raise StandardError, "AO not found for ref_id: #{ref_id}" unless archival_object

        dig_obj_opts = {
          # universal
          content_id: content_id,
          # dcr
          content_title: content_title,
          # cdm
          collection_number: collection_number,
          aspace_container_type: aspace_container_type,
          ao_title: ArchivalObject.to_jsonmodel(archival_object)['title']
        }

        digital_object = get_or_create_digital_object(digital_object_id: digital_object_id, **dig_obj_opts)
        link_dig_obj_archival_obj(archival_object: archival_object, digital_object: digital_object)

        next if source == cdm_source

        # Remove any managed CDM DOs on this AO. They are superseded by the
        # DCR DO we just added.
        #
        # We want to unlink but not delete in case DO is attached to other AOs
        # Any managed DOs made orphans here will be deleted later
        unlink_any_managed_cdm_do(archival_object)
      end

      # Unlink any DO/AO links not present in the data and within scope (scope: none, collections, global)
      #
      # We want to unlink but not delete in case DO is attached to other AOs
      # Any managed DOs made orphans here will be deleted later
      unlink_digital_objects_not_in_upload(scope: deletion_scope)

      delete_orphaned_digital_objects
    end

    private

    def cdm_source
      'cdm'
    end

    def dcr_source
      'dcr'
    end

    # False when a DO for this content is already linked to the AO
    # For CDM, also false if *any* DCR DO is linked to the AO
    def digital_object_needed?(digital_object_id, ref_id)
      return false if managed_digital_object_inventory.fetch(digital_object_id, []).include?(ref_id)
      return true if source == dcr_source

      !dcr_dos?(ref_id)
    end

    # Returns Boolean of whether AO has DCR DOs
    def dcr_dos?(ref_id)
      DigitalObject.
        join(:instance_do_link_rlshp, digital_object_id: :id).
        join(:instance, id: :instance_id).
        join(:archival_object, id: :archival_object_id).
        where(archival_object__ref_id: ref_id).
        where(digital_object__digital_object_id: /^#{dcr_source}:.*/).
        any?
    end

    # A hash storing seen DO:AO linking id pairs
    #
    # If this upload represents a full set of digital content for the given
    # source, any managed DOs not present in this inventory are no longer
    # valid and can be unlinked
    def upload_inventory
      @upload_inventory ||= {}
    end

    # Returns a hash that maps Aspace DO digital_object_id's to an array of
    # their linked ref_ids.
    # Example: {
    #   'dcr:1234-abcd-56-efg' => ['9fe39e2d6843a3455606f1a94aa77d62'],
    #   'dcr:5678-lmno-90-xyz' => ['ac6t8y...', 'e94hys...']
    # }
    def managed_digital_object_inventory
      # The select is to disambiguate between digital_object.digital_object_id
      # and instance_do_link_rlshp.digital_object_id. I tried qualifying the
      # as_hash call with ``:digital_object__digital_object_id` and with
      # `Sequel[:digital_objects][:digital_object_id]` but neither worked.
      # It may be possible to disambiguate in some way and then remove the select
      @managed_digital_object_inventory ||=
        DigitalObject.
          join(:instance_do_link_rlshp, digital_object_id: :id).
          join(:instance, id: :instance_id).
          join(:archival_object, id: :archival_object_id).
          where(digital_object__digital_object_id: /^#{source}:.*/).
          select(:digital_object__digital_object_id, :archival_object__ref_id).
          to_hash_groups(:digital_object_id, :ref_id)
    end

    # Retrieves an existing DO for a DCR URI; creates a DO if none exists
    def get_or_create_digital_object(digital_object_id:, **kwargs)
      existing_dig_obj = DigitalObject.where(digital_object_id: digital_object_id).first
      return DigitalObject.to_jsonmodel(existing_dig_obj) if existing_dig_obj

      jsonmodel = ArchivesSpace::ManagedDigitalObject.from_data(**kwargs).jsonmodel
      DigitalObject.create_from_json(jsonmodel)
    end

    # Adds an instance of a DO to an AO
    def link_dig_obj_archival_obj(archival_object:, digital_object:)
      # We could return early if AO/DO are already linked, but
      # 1) our current sole use in `#handle_datafile` should never call this
      # when the AO/DO are already linked and 2) *maybe* Aspace ignores
      # attempts to add a duplicatative DO instance to an AO?

      # link
      json = ArchivalObject.to_jsonmodel(archival_object)
      instance_json = {'instance_type': 'digital_object',
                       'digital_object': {'ref': digital_object.uri}}
      json['instances'] << instance_json
      archival_object.update_from_json(json)
    end

    def unlink_any_managed_cdm_do(archival_object)
      ArchivalObject.
        join(:instance, archival_object_id: :id).
        join(:instance_do_link_rlshp, instance_id: :id).
        join(:digital_object, id: :digital_object_id).
        where(archival_object__id: archival_object.id).
        where(digital_object__digital_object_id: /^(#{cdm_source}):.*/).
        select(:digital_object__id).
        each do |instance_data|
          unlink_dig_obj_archival_obj(digital_object_record_id: instance_data[:id],
                                      archival_object_id: archival_object.id)
        end
    end

    def unlink_digital_objects_not_in_upload(scope: nil)
      return unless scope && scope != 'none'

      if scope == 'global'
        # Note: adjusting the join order may break things because the select
        # fields aren't qualified (e.g. `id` and `digital_object_id`)
        ArchivalObject.
          join(:instance, archival_object_id: :id).
          join(:instance_do_link_rlshp, instance_id: :id).
          join(:digital_object, id: :digital_object_id).
          where(digital_object__digital_object_id: /^(#{source}):.*/).
          select(:digital_object__digital_object_id, :archival_object__ref_id, :archival_object_id, :digital_object__id).
          each do |instance_data|
            next if upload_inventory.fetch(instance_data[:digital_object_id], []).include?(instance_data[:ref_id])

            unlink_dig_obj_archival_obj(digital_object_record_id: instance_data[:id],
                                        archival_object_id: instance_data[:archival_object_id])
          end
      end
    end

    # `digital_object_record_id` refers to `digital_object.id` and is named such
    # to avoid confusion with `digital_object.digital_object_id`
    def unlink_dig_obj_archival_obj(digital_object_record_id:, archival_object_id:)
      base_ref_uri = "/repositories/#{repo_id}/digital_objects/"
      ao = ArchivalObject[archival_object_id]
      json = ArchivalObject.to_jsonmodel(ao)

      json['instances'] = json['instances'].reject do |instance|
        instance.fetch('digital_object', {})['ref'] == "#{base_ref_uri}#{digital_object_record_id}"
      end
      ao.update_from_json(json)
    end

    # Deletes managed DOs that are orphaned (i.e. that do not have any instances)
    #
    # Note: we do not restrict deletion to orphaned managed DOs from the same
    # source as this management run. DCR management runs and CDM management runs
    # will both delete all orphaned DOs regardless of whether they are DCR or CDM
    def delete_orphaned_digital_objects
      # Note:
      # - digital_object.id is the primary key
      # - digital_object.digital_object_id is a digital_object_id attribute
      # - instance_do_link_rlshp.digital_object_id is a foreign key referencing
      #     the primary key, digital_object.id
      managed_dig_obj_regexp = /^(#{dcr_source}|#{cdm_source}):.*/
      DigitalObject.
        left_join(:instance_do_link_rlshp, digital_object_id: :digital_object__id).
        where(instance_do_link_rlshp__instance_id: nil).
        where(digital_object__digital_object_id: managed_dig_obj_regexp).
        select(:digital_object__id).
        each(&:delete)
    end
  end
end
