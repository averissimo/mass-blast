require_relative 'src/blastn'
require_relative 'src/tblastn'
require 'configatron'
#
#
def run_user_config
  # configuration
  config = YAML.load_file(File.expand_path('config/user.yml'))
  #
  b = nil
  case config['engine']
  when 'tblastn'
    b = TBlastn.new
  when 'blastn'
    b = Blastn.new
  else
    fail "Cannot recognize engine: #{config['engine']}. Please check" \
        ' documentation for implemented engines'
  end
  # blast folders
  b.blast_folders
  # generate report.csv
  b.gen_report_from_output
  # prune results
  b.prune_results
end
#
run_user_config
