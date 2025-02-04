require_relative 'spec_helper'

module ArchivesSpace
  RSpec.describe 'DigitalObjectManager', type: :digital_object_manager do

    let(:spec_log) { StringIO.new }
    let(:manager) do
      manager = DigitalObjectManager.new(source: 'cdm', repo_id: '2')
      manager.logger = Logger.new(spec_log, level: 'DEBUG')
      manager
    end

    describe 'ordering' do
      # An AO with three existing, mis-ordered DOs (ordered "Folder 100...", "Folder 9...", "Test DO [unmanaged]")
      # followed by a newly created DO ("Folder 50")
      let(:presort) do
        JSON.parse(
          '''
          {"id": 1, "lock_version": 7, "json_schema_version": 1, "repo_id": 2, "root_record_id": 1, "parent_name": "root@/repositories/2/resources/1", "position": 0, "publish": false, "ref_id": "fcee5fc2bb61effc8836498a8117b05d", "title": "Test AO", "display_string": "Test AO", "level_id": 893, "other_level": "other", "system_generated": 0, "restrictions_apply": false, "created_by": "admin", "last_modified_by": "admin", "create_time": "2025-01-07T16:25:41Z", "system_mtime": "2025-01-07T17:01:39Z", "user_mtime": "2025-01-07T17:01:39Z", "suppressed": false, "is_slug_auto": false, "level": "otherlevel", "jsonmodel_type": "archival_object", "external_ids": [], "subjects": [], "linked_events": [], "extents": [], "lang_materials": [], "dates": [], "external_documents": [], "rights_statements": [], "linked_agents": [], "import_previous_arks": [], "ancestors": [{"ref": "/repositories/2/resources/1", "level": "collection"}],
          "instances": [
            {"lock_version": 0, "created_by": "admin", "last_modified_by": "admin", "create_time": "2025-01-07T17:01:39Z", "system_mtime": "2025-01-07T17:01:39Z", "user_mtime": "2025-01-07T17:01:39Z", "instance_type": "digital_object", "jsonmodel_type": "instance", "is_representative": false, "digital_object": {"ref": "/repositories/2/digital_objects/7"}},
            {"lock_version": 0, "created_by": "admin", "last_modified_by": "admin", "create_time": "2025-01-07T17:01:39Z", "system_mtime": "2025-01-07T17:01:39Z", "user_mtime": "2025-01-07T17:01:39Z", "instance_type": "digital_object", "jsonmodel_type": "instance", "is_representative": false, "digital_object": {"ref": "/repositories/2/digital_objects/8"}},
            {"lock_version": 0, "created_by": "admin", "last_modified_by": "admin", "create_time": "2025-01-07T17:01:39Z", "system_mtime": "2025-01-07T17:01:39Z", "user_mtime": "2025-01-07T17:01:39Z", "instance_type": "digital_object", "jsonmodel_type": "instance", "is_representative": false, "digital_object": {"ref": "/repositories/2/digital_objects/2"}},
            {"instance_type": "digital_object", "digital_object": {"ref": "/repositories/2/digital_objects/9"}}
          ], "notes": [], "accession_links": [], "uri": "/repositories/2/archival_objects/1", "repository": {"ref": "/repositories/2"}, "resource": {"ref": "/repositories/2/resources/1"}, "has_unpublished_ancestor": true}
          '''
        )
      end

      # The same AO json with DOs resolved
      let(:resolved) do
        JSON.parse(
          '''
          {"lock_version": 7, "position": 0, "publish": false, "ref_id": "fcee5fc2bb61effc8836498a8117b05d", "title": "Test AO", "display_string": "Test AO", "other_level": "other", "restrictions_apply": false, "created_by": "admin", "last_modified_by": "admin", "create_time": "2025-01-07T16:25:41Z", "system_mtime": "2025-01-07T17:01:39Z", "user_mtime": "2025-01-07T17:01:39Z", "suppressed": false, "is_slug_auto": false, "level": "otherlevel", "jsonmodel_type": "archival_object", "external_ids": [], "subjects": [], "linked_events": [], "extents": [], "lang_materials": [], "dates": [], "external_documents": [], "rights_statements": [], "linked_agents": [], "import_previous_arks": [], "ancestors": [{"ref": "/repositories/2/resources/1", "level": "collection"}],
          "instances": [
            {"lock_version": 0, "created_by": "admin", "last_modified_by": "admin", "create_time": "2025-01-07T17:01:39Z", "system_mtime": "2025-01-07T17:01:39Z", "user_mtime": "2025-01-07T17:01:39Z", "instance_type": "digital_object", "jsonmodel_type": "instance", "is_representative": false, "digital_object": {"ref": "/repositories/2/digital_objects/7", "_resolved": {"lock_version": 3, "digital_object_id": "cdm:01234-z_folder_100", "title": "Folder 100: Test AO", "publish": true, "restrictions": false, "created_by": "admin", "last_modified_by": "admin", "create_time": "2025-01-07T16:56:04Z", "system_mtime": "2025-01-07T17:01:39Z", "user_mtime": "2025-01-07T16:56:04Z", "suppressed": false, "is_slug_auto": true, "jsonmodel_type": "digital_object", "external_ids": [], "subjects": [], "linked_events": [], "extents": [], "lang_materials": [], "dates": [], "external_documents": [], "rights_statements": [], "linked_agents": [], "file_versions": [{"lock_version": 0, "file_uri": "https://dc.lib.unc.edu/cdm/search/searchterm/folder_100!01234-z/field/all!all/mode/exact!exact/conn/and!and", "publish": true, "created_by": "admin", "last_modified_by": "admin", "create_time": "2025-01-07T16:56:04Z", "system_mtime": "2025-01-07T16:56:04Z", "user_mtime": "2025-01-07T16:56:04Z", "use_statement": "link", "xlink_actuate_attribute": "onRequest", "xlink_show_attribute": "new", "jsonmodel_type": "file_version", "is_representative": false, "identifier": "7"}], "classifications": [], "notes": [], "collection": [], "linked_instances": [{"ref": "/repositories/2/archival_objects/1"}], "metadata_rights_declarations": [], "uri": "/repositories/2/digital_objects/7", "repository": {"ref": "/repositories/2"}, "tree": {"ref": "/repositories/2/digital_objects/7/tree"}}}},
            {"lock_version": 0, "created_by": "admin", "last_modified_by": "admin", "create_time": "2025-01-07T17:01:39Z", "system_mtime": "2025-01-07T17:01:39Z", "user_mtime": "2025-01-07T17:01:39Z", "instance_type": "digital_object", "jsonmodel_type": "instance", "is_representative": false, "digital_object": {"ref": "/repositories/2/digital_objects/8", "_resolved": {"lock_version": 2, "digital_object_id": "cdm:01234-z_folder_9", "title": "Folder 9: Test AO", "publish": true, "restrictions": false, "created_by": "admin", "last_modified_by": "admin", "create_time": "2025-01-07T16:56:05Z", "system_mtime": "2025-01-07T17:01:39Z", "user_mtime": "2025-01-07T16:56:05Z", "suppressed": false, "is_slug_auto": true, "jsonmodel_type": "digital_object", "external_ids": [], "subjects": [], "linked_events": [], "extents": [], "lang_materials": [], "dates": [], "external_documents": [], "rights_statements": [], "linked_agents": [], "file_versions": [{"lock_version": 0, "file_uri": "https://dc.lib.unc.edu/cdm/search/searchterm/folder_9!01234-z/field/all!all/mode/exact!exact/conn/and!and", "publish": true, "created_by": "admin", "last_modified_by": "admin", "create_time": "2025-01-07T16:56:05Z", "system_mtime": "2025-01-07T16:56:05Z", "user_mtime": "2025-01-07T16:56:05Z", "use_statement": "link", "xlink_actuate_attribute": "onRequest", "xlink_show_attribute": "new", "jsonmodel_type": "file_version", "is_representative": false, "identifier": "8"}], "classifications": [], "notes": [], "collection": [], "linked_instances": [{"ref": "/repositories/2/archival_objects/1"}], "metadata_rights_declarations": [], "uri": "/repositories/2/digital_objects/8", "repository": {"ref": "/repositories/2"}, "tree": {"ref": "/repositories/2/digital_objects/8/tree"}}}},
            {"lock_version": 0, "created_by": "admin", "last_modified_by": "admin", "create_time": "2025-01-07T17:01:39Z", "system_mtime": "2025-01-07T17:01:39Z", "user_mtime": "2025-01-07T17:01:39Z", "instance_type": "digital_object", "jsonmodel_type": "instance", "is_representative": false, "digital_object": {"ref": "/repositories/2/digital_objects/2", "_resolved": {"lock_version": 7, "digital_object_id": "https://example.com/unmanaged-attached", "title": "Test DO", "publish": false, "created_by": "admin", "last_modified_by": "admin", "create_time": "2025-01-07T16:25:41Z", "system_mtime": "2025-01-07T17:01:39Z", "user_mtime": "2025-01-07T16:25:41Z", "suppressed": false, "is_slug_auto": false, "jsonmodel_type": "digital_object", "external_ids": [], "subjects": [], "linked_events": [], "extents": [], "lang_materials": [], "dates": [], "external_documents": [], "rights_statements": [], "linked_agents": [], "file_versions": [{"lock_version": 0, "file_uri": "https://example.com/unmanaged-attached", "created_by": "admin", "last_modified_by": "admin", "create_time": "2025-01-07T16:25:41Z", "system_mtime": "2025-01-07T16:25:41Z", "user_mtime": "2025-01-07T16:25:41Z", "jsonmodel_type": "file_version", "is_representative": false, "identifier": "2"}], "restrictions": false, "classifications": [], "notes": [], "collection": [], "linked_instances": [{"ref": "/repositories/2/archival_objects/1"}], "metadata_rights_declarations": [], "uri": "/repositories/2/digital_objects/2", "repository": {"ref": "/repositories/2"}, "tree": {"ref": "/repositories/2/digital_objects/2/tree"}}}},
            {"instance_type": "digital_object", "digital_object": {"ref": "/repositories/2/digital_objects/9", "_resolved": {"lock_version": 0, "digital_object_id": "cdm:01234-z_folder_50", "title": "Folder 50: Test AO", "publish": true, "restrictions": false, "created_by": "admin", "last_modified_by": "admin", "create_time": "2025-01-07T17:02:12Z", "system_mtime": "2025-01-07T17:02:12Z", "user_mtime": "2025-01-07T17:02:12Z", "suppressed": false, "is_slug_auto": true, "jsonmodel_type": "digital_object", "external_ids": [], "subjects": [], "linked_events": [], "extents": [], "lang_materials": [], "dates": [], "external_documents": [], "rights_statements": [], "linked_agents": [], "file_versions": [{"lock_version": 0, "file_uri": "https://dc.lib.unc.edu/cdm/search/searchterm/folder_50!01234-z/field/all!all/mode/exact!exact/conn/and!and", "publish": true, "created_by": "admin", "last_modified_by": "admin", "create_time": "2025-01-07T17:02:12Z", "system_mtime": "2025-01-07T17:02:12Z", "user_mtime": "2025-01-07T17:02:12Z", "use_statement": "link", "xlink_actuate_attribute": "onRequest", "xlink_show_attribute": "new", "jsonmodel_type": "file_version", "is_representative": false, "identifier": "9"}], "classifications": [], "notes": [], "collection": [], "linked_instances": [], "metadata_rights_declarations": [], "uri": "/repositories/2/digital_objects/9", "repository": {"ref": "/repositories/2"}, "tree": {"ref": "/repositories/2/digital_objects/9/tree"}}}}
          ],
          "notes": [], "accession_links": [], "uri": "/repositories/2/archival_objects/1", "repository": {"ref": "/repositories/2"}, "resource": {"ref": "/repositories/2/resources/1"}, "has_unpublished_ancestor": true}
          '''
          )
      end

      # AO json with DOs properly ordered by title (Folder 9, Folder 50, Folder 100, Test DO)
      let(:expected_sort) do
        JSON.parse(
          '''
          {"id": 1, "lock_version": 7, "json_schema_version": 1, "repo_id": 2, "root_record_id": 1, "parent_name": "root@/repositories/2/resources/1", "position": 0, "publish": false, "ref_id": "fcee5fc2bb61effc8836498a8117b05d", "title": "Test AO", "display_string": "Test AO", "level_id": 893, "other_level": "other", "system_generated": 0, "restrictions_apply": false, "created_by": "admin", "last_modified_by": "admin", "create_time": "2025-01-07T16:25:41Z", "system_mtime": "2025-01-07T17:01:39Z", "user_mtime": "2025-01-07T17:01:39Z", "suppressed": false, "is_slug_auto": false, "level": "otherlevel", "jsonmodel_type": "archival_object", "external_ids": [], "subjects": [], "linked_events": [], "extents": [], "lang_materials": [], "dates": [], "external_documents": [], "rights_statements": [], "linked_agents": [], "import_previous_arks": [], "ancestors": [{"ref": "/repositories/2/resources/1", "level": "collection"}],
          "instances": [
            {"lock_version": 0, "created_by": "admin", "last_modified_by": "admin", "create_time": "2025-01-07T17:01:39Z", "system_mtime": "2025-01-07T17:01:39Z", "user_mtime": "2025-01-07T17:01:39Z", "instance_type": "digital_object", "jsonmodel_type": "instance", "is_representative": false, "digital_object": {"ref": "/repositories/2/digital_objects/8"}},
            {"instance_type": "digital_object", "digital_object": {"ref": "/repositories/2/digital_objects/9"}},
            {"lock_version": 0, "created_by": "admin", "last_modified_by": "admin", "create_time": "2025-01-07T17:01:39Z", "system_mtime": "2025-01-07T17:01:39Z", "user_mtime": "2025-01-07T17:01:39Z", "instance_type": "digital_object", "jsonmodel_type": "instance", "is_representative": false, "digital_object": {"ref": "/repositories/2/digital_objects/7"}},
            {"lock_version": 0, "created_by": "admin", "last_modified_by": "admin", "create_time": "2025-01-07T17:01:39Z", "system_mtime": "2025-01-07T17:01:39Z", "user_mtime": "2025-01-07T17:01:39Z", "instance_type": "digital_object", "jsonmodel_type": "instance", "is_representative": false, "digital_object": {"ref": "/repositories/2/digital_objects/2"}}
          ],
          "notes": [], "accession_links": [], "uri": "/repositories/2/archival_objects/1", "repository": {"ref": "/repositories/2"}, "resource": {"ref": "/repositories/2/resources/1"}, "has_unpublished_ancestor": true}
        '''
        )
      end

      it 'orders new and existing DO instances by DO title', :aggregate_failures do
        allow(manager).to receive(:resolve_references).with(presort, ['digital_object']).and_return(resolved)

        ao_json = presort
        manager.send(:sort_instances!, ao_json)
        expect(ao_json).to eq(expected_sort)
      end
    end

    describe 'delete?' do
      context "deletion_scope is 'none'" do
        it 'returns false' do
          expect(manager.send(:delete?, deletion_scope: 'none',
                              deletion_threshold: nil)).to be false
        end
      end

      context "deletion_scope is nil" do
        it 'returns false' do
          expect(manager.send(:delete?, deletion_scope: nil,
                              deletion_threshold: nil)).to be false
        end
      end

      context "deletion_scope is not 'none'/nil"
        context 'submitted data contains fewer records than the deletion_threshold threshold' do
          it 'raises an UnmetDeletionThresholdError' do
            expect { manager.send(:delete?, deletion_scope: 'foo', record_count: 2,
                                deletion_threshold: 3) }.
              to raise_error(ArchivesSpace::DigitalObjectManager::UnmetDeletionThresholdError)
          end
        end

        context 'submitted records number >= than the deletion_threshold threshold' do
          it 'returns true' do
            expect(manager.send(:delete?, deletion_scope: 'foo', record_count: 2,
                                deletion_threshold: 2)).to be true
          end
        end

        context 'deletion_threshold is not set' do
          it 'returns true' do
            expect(manager.send(:delete?, deletion_scope: 'foo',
                                deletion_threshold: nil)).to be true
          end
        end
    end
  end
end
