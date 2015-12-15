require_relative 'blastn'
require_relative 'tblastn'

b = TBlastn.new('config_tblastn.yml') # create Blast object
b.blast_folders # blast folders
b.gen_report_from_output # generate report.csv
b.prune_results
