require_relative 'spec_helper'
require_relative 'blast_helpers'

RSpec.configure do |c|
  c.extend BlastHelpers
end

RSpec.describe Blast do
  #
  REPORT_FILE = 'report.csv'
  #
  describe Blastn do
    #
    type = 'blastn'
    b = Blastn.new(test_config(type))
    b.blast_folders
    b.gen_report_from_output
    b.prune_results

    output_dir = b.store.output.dir
    #
    context 'all files should be equal' do
      test_results(type, output_dir).each do |file_hash|
        it "testing if '#{File.basename(file_hash[:expected])}'" \
          'are identical' do
          expect(FileUtils.compare_file(file_hash[:expected],
                                        file_hash[:output])).to be_truthy
        end
      end
    end
  end
end
