require "./blast"

# example for dbs named 'c1', 'c2' and 'c1_l1_2'
dbs = ["c1","c2", "c1_l1_2"]
# example for queries in folders: 'kegg_queries' and 'ncbi_queries'
queries = ["kegg_queries","ncbi_queries"]
# create Blast object
b = Blast.new( dbs )
#
# example of performing just one blast query
#b.blastn('kegg_queries/quer1cetin.query',"c2", "out/test.out")
#
# blast folders
b.blastn_folders( queries )
b.gen_report_from_output
