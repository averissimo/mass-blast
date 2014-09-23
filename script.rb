require "./blast"

dbs = ["c1","c2", "c1_l1_2"]
queries = ["kegg_queries","ncbi_queries"]
b = Blast.new( dbs )
#b.blastn_folders( queries )
#b.blastn('kegg_queries/quer1cetin.query',"c2", "out/test.out")
b.gen_report_from_output
