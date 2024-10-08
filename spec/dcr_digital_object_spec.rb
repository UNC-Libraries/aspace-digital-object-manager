require_relative 'spec_helper'

module ArchivesSpace
  RSpec.describe 'DcrDigitalObject', type: :digital_object_manager do
    let(:content_data) do
      DigitalContentData.new(source: 'dcr',
                             content_id: '12345678-abcd-abcd-abcd-1234567890ab',
                             ref_id: 'fcee5fc2bb61effc8836498a8117b05d',
                             content_title: 'My Work Title')
    end
    let(:dcr_dig_obj) { DcrDigitalObject.new(content_data) }

    describe '#jsonmodel' do
      let(:subject) { dcr_dig_obj.jsonmodel }

      before(:each) do
        allow(dcr_dig_obj).to receive(:bare_dig_obj_jsonmodel).and_return(bare_dig_obj_jsonmodel)
      end

      it 'returns correct DCR jsonmodel', :aggregate_failures do
        expect(subject['jsonmodel_type']).to eq('digital_object')
        expect(subject['digital_object_id']).to eq('dcr:12345678-abcd-abcd-abcd-1234567890ab')
        expect(subject['title']).to eq('My Work Title')
        expect(subject['publish']).to be true
        expect(subject['file_versions'].length).to eq(1)
        expect(subject['file_versions'].first['file_uri']).to eq('https://dcr.lib.unc.edu/record/12345678-abcd-abcd-abcd-1234567890ab')
        expect(subject['file_versions'].first['publish']).to be true
        expect(subject['file_versions'].first['use_statement']).to eq('link')
        expect(subject['file_versions'].first['xlink_actuate_attribute']).to eq('onRequest')
        expect(subject['file_versions'].first['xlink_show_attribute']).to eq('new')
      end
    end
  end
end
