$LOAD_PATH.unshift File.expand_path('../backend/lib', __dir__)
require 'rspec'

require 'digital_object_manager'
require 'managed_digital_object'
require 'cdm_digital_object'
require 'dcr_digital_object'


RSpec.shared_context "digital object manager helpers" do
  let(:bare_dig_obj_jsonmodel) do
    {
      "jsonmodel_type"=>"digital_object",
      "external_ids"=>[],
      "subjects"=>[],
      "linked_events"=>[],
      "extents"=>[],
      "lang_materials"=>[],
      "dates"=>[],
      "external_documents"=>[],
      "rights_statements"=>[],
      "linked_agents"=>[],
      "is_slug_auto"=>true,
      "file_versions"=>[],
      "restrictions"=>false,
      "classifications"=>[],
      "notes"=>[],
      "collection"=>[],
      "linked_instances"=>[],
      "metadata_rights_declarations"=>[]
    }
  end
end

RSpec.configure do |config|
  config.include_context "digital object manager helpers", :type => :digital_object_manager
end
