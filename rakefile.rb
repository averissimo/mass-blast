require 'rake/testtask'
require 'rake/clean'
require 'byebug'

Rake::TestTask.new do |t|
  t.libs << 'test'
  t.test_files = FileList['test/tc*.rb']
  t.verbose = true
end

Rake::FileList.new('output/*') do |fl|
  CLOBBER << fl
  CLEAN << fl
end
