require_relative 'src/blastn'
require_relative 'src/tblastn'
require_relative 'src/download'

require 'configatron'
#
#
def run_user_config
  # configuration
  if ARGV.empty?
    config = YAML.load_file(File.expand_path('config/user.yml'))
  else
    config = YAML.load_file(File.expand_path(ARGV[0]))
  end
  #
  b = nil
  case config['engine']
  when 'tblastn'
    b = TBlastn.new(ARGV[0])
  when 'blastn'
    b = Blastn.new ARGV[0]
  else
    fail "Cannot recognize engine: #{config['engine']}. Please check" \
        ' documentation for implemented engines'
  end
  # download taxdb from ncbi
  ExternalData.download(config['db', 'parent'])
  # blast folders
  b.blast_folders
  # generate report.csv
  b.gen_report_from_output
  # prune results
  b.prune_results
end
#
run_user_config
