require_relative 'spec_helper'

module ArchivesSpace
  RSpec.describe 'CdmDigitalObject', type: :digital_object_manager do

    def jsonmodel_from_content_data(content_data)
      digital_content_data = DigitalContentData.new(content_data)
      cdm_dig_obj = CdmDigitalObject.new(digital_content_data)
      allow(cdm_dig_obj).to receive(:bare_dig_obj_jsonmodel).and_return(bare_dig_obj_jsonmodel)
      cdm_dig_obj.jsonmodel
    end

    let(:content_data) do
      {
        source: 'cdm',
        content_id: '01234_box_5',
        ref_id: 'fcee5fc2bb61effc8836498a8117b05d',
        collection_number: '01234-z',
        aspace_hookid: '01234_documentcase_5678',
        cdm_alias: '01ddd',
        ao_title: 'My AO Title'
      }
    end

    describe '#jsonmodel' do
      let(:subject) { jsonmodel_from_content_data(content_data) }

      it 'returns correct CDM jsonmodel', :aggregate_failures do
        expect(subject['jsonmodel_type']).to eq('digital_object')
        expect(subject['digital_object_id']).to eq('cdm:01234-z_box_5')
        expect(subject['title']).to eq('Document Case 5: My AO Title')
        expect(subject['publish']).to be true
        expect(subject['file_versions'].length).to eq(1)
        expect(subject['file_versions'].first['file_uri']).to eq('https://dc.lib.unc.edu/cdm/search/collection/01ddd/searchterm/box_5!01234-z/field/all!all/mode/exact!exact/conn/and!and/order/relatid')
        expect(subject['file_versions'].first['publish']).to be true
        expect(subject['file_versions'].first['use_statement']).to eq('link')
        expect(subject['file_versions'].first['xlink_actuate_attribute']).to eq('onRequest')
        expect(subject['file_versions'].first['xlink_show_attribute']).to eq('new')
      end

      describe 'character escaping in titles' do
        it 'unescapes tabs and backslashes in title' do
          # we're passing the literal escape sequences `\t` and `\\``
          content_data[:ao_title] = "My AO Title with \\t tab and \\\\ backslash"
          expect(subject['title']).to eq("Document Case 5: My AO Title with \t tab and \\ backslash")
        end

        it 'literal tabs and backslashes remain literal in title' do
          # we're passing a literal tab and literal backslash`
          content_data[:ao_title] = "My AO Title with \t tab and \\ backslash"
          expect(subject['title']).to eq("Document Case 5: My AO Title with \t tab and \\ backslash")
        end

        it 'Aspace titles can still contain literal escape sequences' do
          # passing `\\t` and `\\\\` to get `\t` and `\\` in the titles`
          content_data[:ao_title] = 'My AO Title with \\\\t tab and \\\\\\\\ backslash'
          expect(subject['title']).to eq('Document Case 5: My AO Title with \\t tab and \\\\ backslash')
        end
      end
    end
  end
end
