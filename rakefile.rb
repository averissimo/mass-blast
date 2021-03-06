require 'rake/testtask'
require 'rake/clean'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec) do |t|
  Rake::Task['bootstrap'].invoke
  Rake::Task['spec:db'].invoke
  t.pattern = Dir.glob('test/test_*.rb')
  t.rspec_opts = '--format documentation'
  # t.rspec_opts << ' more options'
end

RSpec::Core::RakeTask.new(:'spec:db') do |t|
  t.pattern = Dir.glob('test/test_results_db.rb')
  t.rspec_opts = '--format documentation'
  # t.rspec_opts << ' more options'
end

task default: :bootstrap

desc 'Download all external databases'
task :bootstrap do
  require_relative 'src/download'
  ExternalData.download
end

Rake::FileList.new('output/*',
                   'test/db/*.nin', 'test/db/*.nhr', 'test/db/*.nsq',
                   '**/db/*.btd', '**/db/*.bti') do |fl|
  CLOBBER << fl
  CLEAN << fl
end
