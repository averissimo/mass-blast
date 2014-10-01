MassBLAST
==========

Library to query multiple files against many databases

# How to use

- Options are configurable via `config.yml` file
  - Change 'db_parent' and 'query_parent' to specify the parent directories for blast databases and queries
  - Change 'dbs' and 'folder_queries' to specify the databases that should be used and which query folders should be crawled
- run `ruby script.rb`

## Methods available

- blastn(qfile, db, out_file, query_parent=nil, db_parent=nil)
  - *qfile*: query file path - string
  - *db*: database name - string
  - *out_file*: output file path (can be relative) -string
  - *query_parent*: parent directory of query (optional) - string
  - *db_parent*: parent directory of database (optional) - string

*notes:* '*qfile*' and '*db*' arguments can be relative to '*query_parent*' and '*db_parent*' (respectively).

- blastn_folders( folders=nil, query_parent=nil, db_parent=nil )
  - *folders*: list of folders (optional) - array of strings
  - *query_parent*: parent directory of folders (optional) - string
  - *db_parent*: parent directory of database (optional) - string

*notes:* '*folder*' argument can be relative to '*query_parent*'.

all optional parameters must be set in the config.yml file

## Relation with other tools

- [Gene Extractor](https://github.com/averissimo/gene-extractor/): can be used to extract genes from Kegg2 and GenBank using keyword search.

## Ackowledgements

This tool was created as a part of [FCT](www.fct.p) grant SFRH/BD/97415/2013 and European Commission research project [BacHBerry](www.bachberry.eu) (FP7- 613793)

[Developer](http://web.tecnico.ulisboa.pt/andre.verissimo/)
