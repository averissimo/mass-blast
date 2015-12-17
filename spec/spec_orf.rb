require_relative 'spec_helper'

#
#
RSpec.describe ORF do
  describe '#nt' do
    #
    parent = File.expand_path(File.join('spec', 'find_orfs'))
    # file that contains all tests

    context 'synthetic test input' do
      YAML.load_file(File.join(parent, 'synthetic.yml'))['test']
        .each_with_index do |item, index|
        #
        it "hashes shoud match in test \##{index}" do
          orf = ORF.new(item['input'], symbolize_keys(item['config']))
          orf.find
          expect(orf.nt).to eq(symbolize_keys(item['output']))
        end
      end
    end

    context 'real test input' do
      YAML.load_file(File.join(parent, 'real.yml'))['test']
        .each_with_index do |item, index|
        #
        it "hashes shoud match in test \##{index}" do
          orf = ORF.new(item['input'], symbolize_keys(item['config']))
          orf.find
          expect(orf.nt).to eq(symbolize_keys(item['output']))
        end
      end
    end
  end
end
