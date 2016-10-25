require_relative 'test_helper'
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
        lines_expected = IO.readlines(file_hash[:expected])
        lines_output   = IO.readlines(file_hash[:output])
        it "testing if '#{File.basename(file_hash[:expected])}'" \
          'are identical' do
          expect(lines_expected.size == lines_output.size &&
                 compare_lines(lines_expected, lines_output)).to be_truthy
        end
      end
    end
  end
end
