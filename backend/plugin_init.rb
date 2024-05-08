# frozen_string_literal: true

# require files from lib
# `.reverse` is a hack to get managed_digital_object.rb loaded before cdm/dcr_digital_object
Dir.glob(File.join(File.dirname(__FILE__), 'lib', '*.rb')).sort.reverse.each do |file|
  require File.absolute_path(file)
end
