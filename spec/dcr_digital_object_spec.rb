require_relative 'spec_helper'

module ArchivesSpace
  RSpec.describe 'DcrDigitalObject', type: :digital_object_manager do

    def jsonmodel_from_content_data(content_data)
      digital_content_data = DigitalContentData.new(content_data)
      dcr_dig_obj = DcrDigitalObject.new(digital_content_data)
      allow(dcr_dig_obj).to receive(:bare_dig_obj_jsonmodel).and_return(bare_dig_obj_jsonmodel)
      dcr_dig_obj.jsonmodel
    end

    let(:content_data) do
      {
        source: 'dcr',
        ref_id: 'fcee5fc2bb61effc8836498a8117b05d',
        content_id: '12345678-abcd-abcd-abcd-1234567890ab',
        content_title: 'My Work Title',
        content_type: 'image'
      }
    end

    describe '#jsonmodel' do
      let(:subject) { jsonmodel_from_content_data(content_data) }

      it 'returns correct DCR jsonmodel', :aggregate_failures do
        expect(subject['jsonmodel_type']).to eq('digital_object')
        expect(subject['digital_object_id']).to eq('dcr:12345678-abcd-abcd-abcd-1234567890ab')
        expect(subject['title']).to eq('My Work Title')
        expect(subject['publish']).to be true
        expect(subject['file_versions'].length).to eq(1)
        expect(subject['file_versions'].first['file_uri']).to eq('https://dcr.lib.unc.edu/record/12345678-abcd-abcd-abcd-1234567890ab')
        expect(subject['file_versions'].first['publish']).to be true
        expect(subject['file_versions'].first['use_statement']).to eq('image')
        expect(subject['file_versions'].first['xlink_actuate_attribute']).to eq('onRequest')
        expect(subject['file_versions'].first['xlink_show_attribute']).to eq('new')
      end

      context 'when content_type is not provided' do
        it "uses 'link' as a default use_statement" do
          content_data.delete(:content_type)
          expect(subject['file_versions'].first['use_statement']).to eq('link')
        end
      end
    end

    describe '.validate' do
      let(:subject) { DcrDigitalObject.validate(DigitalContentData.new(content_data)) }

      it 'succeeds for valid input data' do
        expect { subject }.not_to raise_error
      end

      it 'fails for wrongly structured ref_ids' do
        content_data[:ref_id] = 'abcd'
        expect { subject }.to raise_error(ArchivesSpace::ManagedDigitalObject::ValidationError)
      end

      it 'fails for nil ref_ids' do
        content_data.delete(:ref_id)
        expect { subject }.to raise_error(ArchivesSpace::ManagedDigitalObject::ValidationError)
      end

      it 'fails for wrongly structured content_ids (expects UUIDs)' do
        content_data[:content_id] = 'abcd'
        expect { subject }.to raise_error(ArchivesSpace::ManagedDigitalObject::ValidationError)
      end

      it 'fails for nil content_id (UUIDS)' do
        content_data.delete(:content_id)
        expect { subject }.to raise_error(ArchivesSpace::ManagedDigitalObject::ValidationError)
      end

      it 'succeeds for content_titles that include tabs' do
        content_data[:content_title] = "Some Title with a literal tab: \t"
        expect { subject }.not_to raise_error
      end

      it 'fails for content_titles that include control characters' do
        content_data[:content_title] = "Some Title with \x00 control character"
        expect { subject }.to raise_error(ArchivesSpace::ManagedDigitalObject::ValidationError)
      end

      it 'fails for content_titles that are empty' do
        content_data[:content_title] = ''
        expect { subject }.to raise_error(ArchivesSpace::ManagedDigitalObject::ValidationError)
      end

      it 'fails for nil content_titles' do
        content_data.delete(:content_title)
        expect { subject }.to raise_error(ArchivesSpace::ManagedDigitalObject::ValidationError)
      end

      it 'fails for unrecognized content_types' do
        content_data[:content_type] = 'some_unexpected_value'
        expect { subject }.to raise_error(ArchivesSpace::ManagedDigitalObject::ValidationError)
      end

      it 'succeeds for nil content_type' do
        content_data.delete(:content_type)
        expect { subject }.not_to raise_error
      end
    end
  end
end
