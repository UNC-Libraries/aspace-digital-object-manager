require_relative 'spec_helper'

module ArchivesSpace
  RSpec.describe 'CdmDigitalObject', type: :digital_object_manager do
    let(:content_data) do
      DigitalContentData.new(
        source: 'cdm',
        content_id: '01234_box_5',
        ref_id: 'fcee5fc2bb61effc8836498a8117b05d',
        collection_number: '01234-z',
        aspace_hookid: '01234_documentcase_5678'
      )
    end
    let(:cdm_dig_obj) { CdmDigitalObject.new(content_data, ao_title: 'My AO Title') }

    describe '#jsonmodel' do
      let(:subject) { cdm_dig_obj.jsonmodel }

      before(:each) do
        allow(cdm_dig_obj).to receive(:bare_dig_obj_jsonmodel).and_return(bare_dig_obj_jsonmodel)
      end

      it 'returns correct CDM jsonmodel', :aggregate_failures do
        expect(subject['jsonmodel_type']).to eq('digital_object')
        expect(subject['digital_object_id']).to eq('cdm:01234-z_box_5')
        expect(subject['title']).to eq('Document Case 5: My AO Title')
        expect(subject['publish']).to be true
        expect(subject['file_versions'].length).to eq(1)
        expect(subject['file_versions'].first['file_uri']).to eq('https://dc.lib.unc.edu/cdm/search/searchterm/box_5!01234-z/field/all!all/mode/exact!exact/conn/and!and')
        expect(subject['file_versions'].first['publish']).to be true
        expect(subject['file_versions'].first['use_statement']).to eq('link')
        expect(subject['file_versions'].first['xlink_actuate_attribute']).to eq('onRequest')
        expect(subject['file_versions'].first['xlink_show_attribute']).to eq('new')
      end
    end
  end
end
