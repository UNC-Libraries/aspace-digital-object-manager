# frozen_string_literal: true

require 'json'

require_relative 'digital_content_data'

module ArchivesSpace
  class DigitalObjectManager
    attr_reader :source, :repo_id

    # Booleans for whether CDM and DCR DOs are managed are not.
    # These allow us to skip certain processing steps until we are actually
    # managing DCR DOs and skip certain steps once we are no longer managing
    # CDM DOs
    CDM_MANAGED = true
    DCR_MANAGED = true

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
      log.info('Starting')
      log.info('Beginning DO creation')
      # To avoid a single large transaction, we split input into 50 row chunks
      # and create a transaction for each chunk.
      CSV.open(datafile, headers: true).lazy.each_slice(50) do |slice|
        # This begin / DB.open / rescue wrapping was taken from:
        #   `archivesspace/backend/app/contollers/batch_import.rb`
        client_errors_present = false
        server_errors_present = false

        DB.open(DB.supports_mvcc?,
                :retry_on_optimistic_locking_fail => true,
                :isolation_level => :committed) do
          slice.each do |row|
            DB.transaction(savepoint: true) do
              begin
                input_data = DigitalContentData.new(
                  # universal
                  source: source,
                  content_id: row['content_id'] || row['uuid'] || row['cache_hookid'],
                  ref_id: row['ref_id'],
                  # dcr
                  content_title: row['content_title'] || row['work_title'],
                  # cdm
                  collection_number: row['collid'],
                  aspace_hookid: row['aspace_hookid']
                )

                digital_object_id = input_data.digital_object_id
                ref_id = input_data.ref_id

                if deletion_scope && deletion_scope != 'none'
                  upload_inventory[digital_object_id] ||= []
                  upload_inventory[digital_object_id] << ref_id
                end

                next unless digital_object_needed?(digital_object_id, ref_id)

                # For performance, defer validation until we screen out data
                # for which a DO already exists
                input_data.validate

                archival_object = ArchivalObject.find(ref_id: ref_id)
                unless archival_object
                  raise RefIDNotFoundError, "AO not found for ref_id: #{ref_id}"
                end
                archival_object_json = ArchivalObject.to_jsonmodel(archival_object)

                digital_object = get_or_create_digital_object(
                  input_data,
                  ao_title: archival_object_json['title']
                )

                add_digital_object_instance!(archival_object_json: archival_object_json,
                                            digital_object: digital_object)

                # Remove any managed CDM DOs on this AO. They are superseded by the
                # DCR DO we just added.
                # We want to unlink but not delete in case DO is attached to other AOs
                # Any managed DOs made orphans here will be deleted later
                if source == dcr_source && CDM_MANAGED
                  unlink_any_managed_cdm_do!(archival_object_json, archival_object)
                end

                update_archival_object(archival_object, archival_object_json)
              rescue ManagedDigitalObject::ValidationError, RefIDNotFoundError => e
                client_errors_present = true
                log.warn(e.message)

                # Roll back to the savepoint
                raise Sequel::Rollback, e
              rescue JSONModel::ValidationException, ImportException, Sequel::ValidationFailed, ReferenceError => e
                # Note: we deliberately don't catch Sequel::DatabaseError here.  The
                # outer call to DB.open will catch that exception and retry the
                # import for us.

                server_errors_present = true
                log.warn(e)

                # Roll back to the savepoint
                raise Sequel::Rollback, e
              end
            end
          end
        end
      end

       # Unlink any DO/AO links not present in the data and within scope (scope: none, global)
       # We want to unlink but not delete in case DO is attached to other AOs
       # Any managed DOs made orphans here will be deleted later
      if deletion_scope && deletion_scope != 'none'
        log.info('Beginning unlinking')
        DB.open(DB.supports_mvcc?,
                :retry_on_optimistic_locking_fail => true,
                :isolation_level => :committed) do
          unlink_digital_objects_not_in_datafile(scope: deletion_scope)
        end

        log.info('Beginning orphaned DO deletion')
        delete_orphaned_digital_objects
      end

      # TODO: return something if errors present
      log.info('Finished')
    end

    class RefIDNotFoundError < RuntimeError; end

    private

    def log
      return @logger if @logger

      unless AppConfig.has_key?(:digital_object_manager_log)
        AppConfig[:digital_object_manager_log] = '/opt/archivesspace/logs/digital_object_manager.log'
      end

      unless AppConfig.has_key?(:digital_object_manager_log_level)
        AppConfig[:digital_object_manager_log_level] = 'warn'
      end

      output = AppConfig[:digital_object_manager_log]
      level = AppConfig[:digital_object_manager_log_level].upcase
      @logger = Logger.new(output, level: level)
    end

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

      !DCR_MANAGED || !dcr_dos?(ref_id)
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
    # Example: {
    #   'dcr:1234-abcd-56-efg' => ['9fe39e2d6843a3455606f1a94aa77d62'],
    #   'dcr:5678-lmno-90-xyz' => ['ac6t8y...', 'e94hys...']
    # }
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
    def get_or_create_digital_object(input_data, **kwargs)
      existing_dig_obj = DigitalObject.where(digital_object_id: input_data.digital_object_id).first
      return DigitalObject.to_jsonmodel(existing_dig_obj) if existing_dig_obj

      jsonmodel = input_data.digital_object(**kwargs).jsonmodel
      DigitalObject.create_from_json(jsonmodel)
    end

    # *Updates an AO in Aspace* according to the archival_object_json given
    def update_archival_object(archival_object, archival_object_json)
      archival_object.update_from_json(archival_object_json)
    end

    # Adds an instance of a DO to an AO jsonmodel
    def add_digital_object_instance!(archival_object_json:, digital_object:)
      # We could return early if AO/DO are already linked, but
      # 1) our current sole use in `#handle_datafile` should never call this
      # when the AO/DO are already linked and 2) *maybe* Aspace ignores
      # attempts to add a duplicatative DO instance to an AO?

      # link
      instance_json = {'instance_type': 'digital_object',
                       'digital_object': {'ref': digital_object.uri}}
      archival_object_json['instances'] << instance_json
    end

    def unlink_digital_objects_not_in_datafile(scope: nil)
      return unless scope && scope != 'none'

      if scope == 'global'
        # Note: adjusting the join order may break things because the select
        # fields aren't qualified (e.g. `id` and `digital_object_id`)
        instance_deletes_by_ao = {}
        managed_digital_object_inventory.each do |do_id, ref_ids|
          next if upload_inventory.fetch(do_id, []).sort == ref_ids.sort

          delete_ref_ids = ref_ids - upload_inventory.fetch(do_id, [])
          delete_ref_ids.each do |ref_id|
            instance_deletes_by_ao[ref_id] ||= []
            instance_deletes_by_ao[ref_id] << do_id
          end
        end

        # Group deletions by AO so that deleting multiple DOs from an
        # AO only results in one AO update
        instance_deletes_by_ao.each do |ref_id, deletions|
          DB.transaction(savepoint: true) do
            base_ref_uri = "/repositories/#{repo_id}/digital_objects/"

            ao = ArchivalObject.first(ref_id: ref_id)
            json = ArchivalObject.to_jsonmodel(ao)

            deletions.each do |digital_object_id|
              digital_object = DigitalObject.first(digital_object_id: digital_object_id)
              next unless digital_object

              json['instances'] = json['instances'].reject do |instance|
                instance.fetch('digital_object', {})['ref'] == "#{base_ref_uri}#{digital_object[:id]}"
              end
            end

            ao.update_from_json(json)
          end
        end
      end
    end

    def unlink_any_managed_cdm_do!(archival_object_json, archival_object)
      ArchivalObject.
        join(:instance, archival_object_id: :id).
        join(:instance_do_link_rlshp, instance_id: :id).
        join(:digital_object, id: :digital_object_id).
        where(archival_object__id: archival_object.id).
        where(digital_object__digital_object_id: /^(#{cdm_source}):.*/).
        select(:digital_object__id).
        each do |instance_data|
          unlink_dig_obj_from_json!(archival_object_json: archival_object_json,
                                   digital_object_record_id: instance_data[:id])
        end
    end

    # `digital_object_record_id` refers to `digital_object.id` and is named such
    # to avoid confusion with `digital_object.digital_object_id`
    def unlink_dig_obj_from_json!(archival_object_json:, digital_object_record_id:)
      base_ref_uri = "/repositories/#{repo_id}/digital_objects/"

      archival_object_json['instances'] = archival_object_json['instances'].reject do |instance|
        instance.fetch('digital_object', {})['ref'] == "#{base_ref_uri}#{digital_object_record_id}"
      end
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
