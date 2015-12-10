require_relative '../orf'

require 'yaml'
require 'logger'
require 'test/unit'
require 'byebug'

#
#
#
class TestORF < Test::Unit::TestCase
  #
  def test_longest
    parent = File.expand_path(File.join('test', 'find_orfs'))
    Dir.foreach(parent) do |item|
      test_file = File.join(parent, item)
      next unless File.file?(test_file) && File.extname(test_file) == '.yml'
      data_file = YAML.load_file(test_file)
      assert_equal(data_file['output'],
                   ORF.find_longest(data_file['input'])[:nt].to_s)
    end
  end
end
