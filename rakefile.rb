require 'rake/testtask'
require 'rake/clean'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec) do |t|
  t.pattern = Dir.glob('spec/**/spec_*.rb')
  t.rspec_opts = '--format documentation'
  # t.rspec_opts << ' more options'
end

Rake::FileList.new('output/*') do |fl|
  CLOBBER << fl
  CLEAN << fl
end
