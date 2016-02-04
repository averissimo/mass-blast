require_relative '../src/blast'
require_relative '../src/blastn'
require_relative '../src/tblastn'
require_relative '../src/tblastx'

require 'yaml'
require 'rspec'

def symbolize_keys(old_hash)
  new_hash = {}
  old_hash.keys.each do |key|
    new_hash[key.to_sym] = old_hash[key]
  end
  new_hash
end
