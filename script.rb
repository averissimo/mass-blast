require_relative 'src/run.rb'
#
run_user_config((ARGV.empty? ? 'user.yml' : ARGV[0]))
