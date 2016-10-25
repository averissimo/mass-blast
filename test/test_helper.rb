require_relative '../src/blast'
require_relative '../src/blastn'
require_relative '../src/tblastn'
require_relative '../src/tblastx'

require 'yaml'
require 'rspec'

def compare_lines(lines1, lines2)
  lines1.each_with_index do |line1, ix|
    return false unless line1.strip == lines2[ix].strip
  end
  true
end

def symbolize_keys(old_hash)
  new_hash = {}
  old_hash.keys.each do |key|
    new_hash[key.to_sym] = old_hash[key]
  end
  new_hash
end
