require 'rake/testtask'
require 'rake/clean'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec) do |t|
  t.pattern = Dir.glob('spec/**/spec_*.rb')
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
                   '**/db/*.nin', '**/db/*.nhr', '**/db/*.nsq',
                   '**/db/*.btd', '**/db/*.bti') do |fl|
  CLOBBER << fl
  CLEAN << fl
end
