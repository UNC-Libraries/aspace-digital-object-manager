require_relative 'spec_helper'

module ArchivesSpace
  RSpec.describe 'ManagedDigitalObject', type: :digital_object_manager do
    describe '#partially_unescape_title' do
      def unescape(title)
        ManagedDigitalObject.partially_unescape_title(title)
      end
      
      it 'unescapes `\t`' do
        expect(unescape("\\t")).to eq("\t")
      end

      it 'unescapes `\\`' do
        expect(unescape("\\\\")).to eq("\\")
      end

      it 'does not unescape every special character' do
        expect(unescape("\\n")).to eq("\\n")
      end

      it "literal '\t' can be represented by '\\t'" do
        expect(unescape('\\\\t')).to eq('\\t')
      end

      it "literal '\\' can be represented by '\\\\'" do
        expect(unescape("\\\\\\\\")).to eq("\\\\")
      end

      it "backslash followed by tab can be represented by '\\\t'" do
        expect(unescape('\\\\\\t')).to eq("\\\t")
      end

      it 'literal tabs are unaffected' do
        expect(unescape('	')).to eq("\t")
      end
    end
  end
end
