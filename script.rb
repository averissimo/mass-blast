require_relative 'src/blastn'
require_relative 'src/tblastn'

b = Blastn.new('config/config.yml') # create Blast object
b.blast_folders # blast folders
b.gen_report_from_output # generate report.csv
b.prune_results
