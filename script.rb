require_relative 'src/run.rb'
#
run_user_config((ARGV.empty? ? 'user.yml' : ARGV[0]))
#
# benchmarking
#
# for benchmarking a run 5 times do:
# run_user_config((ARGV.empty? ? 'user.yml' : ARGV[0]), 5)
