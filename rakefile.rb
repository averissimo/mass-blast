require 'rake/testtask'
require 'rake/clean'
require 'byebug'



Rake::TestTask.new do |t|
  t.name = 'test_orf'
  t.libs << 'test'
  t.test_files = FileList['test/test_orf.rb']
  t.verbose = true
end

Rake::TestTask.new do |t|
  t.libs << 'test'
  t.test_files = FileList['test/test_*.rb']
  t.verbose = true
end

Rake::FileList.new('output/*') do |fl|
  CLOBBER << fl
  CLEAN << fl
end
