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
    test_file = File.join(parent, 'data.yml')
    data_file = YAML.load_file(test_file)
    data_file['test'].each do |item|
      orf = ORF.new(item['input'])
      orf.find
      assert_equal(symbolize_keys(item['output']), orf.nt)
    end
  end

  private

  def symbolize_keys(old_hash)
    new_hash = {}
    old_hash.keys.each do |key|
      new_hash[key.to_sym] = old_hash[key]
    end
    new_hash
  end
end
