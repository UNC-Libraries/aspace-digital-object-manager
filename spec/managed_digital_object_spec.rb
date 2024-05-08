require_relative 'spec_helper'

module ArchivesSpace
  RSpec.describe 'ManagedDigitalObject', type: :digital_object_manager do
    describe '.from_data' do
      context 'when given a content_id in Work UUID format' do
        it 'returns a DcrDigitalObject' do
          opts = {content_id: '12345678-abcd-abcd-abcd-1234567890ab',
                  content_title: 'Title'}
          expect(ManagedDigitalObject.from_data(**opts)).to be_instance_of DcrDigitalObject
        end
      end

      context 'when given a content_id in cache hookID format' do
        it 'returns a CdmDigitalObject' do
          opts = {content_id: '01234_folder_1',
                  collection_number: 'HC0010',
                  aspace_container_type: 'folder',
                  ao_title: 'Title'}
          expect(ManagedDigitalObject.from_data(**opts)).to be_instance_of CdmDigitalObject
        end
      end

      context 'when given content_id with unexpected format' do
        it 'raises an error' do
          expect { ManagedDigitalObject.from_data(content_id: 'box_1') }.to raise_error(StandardError)
        end
      end
    end
  end
end
