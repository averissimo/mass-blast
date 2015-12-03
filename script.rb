require './blastn.rb'

b = Blastn.new # create Blast object
b.blast_folders # blast folders
b.gen_report_from_output # generate report.csv
