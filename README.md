MassBLAST
==========

Library to query multiple files against many databases

# How to use

- Options are configurable via `config/user.yml` file
  - Change 'db_parent' and 'query_parent' to specify the parent directories for blast databases and queries
  - Change 'dbs' and 'folder_queries' to specify the databases that should be used and which query folders should be crawled

        ruby script.rb

## External data

The test blast database and the taxonomy database are not kept in the git tree anymore, to get this auxiliary data run the command below or call mass-blast via script.rb

        ruby bootstrap.rb

If you need to include it on your code use:

    require_relative 'src/download'

    ExternalData.download(path_to_db_parent)

## How to test it

        rake spec

## Type of blast implemented

- Blastn
- TBlastn
- TBlastx

## Methods available

All different types have two implemented methods, blast and blast_folders

- blast(qfile, db, out_file, query_parent=nil, db_parent=nil)
  - *qfile*: query file path - string
  - *db*: database name - string
  - *out_file*: output file path (can be relative) -string
  - *query_parent*: parent directory of query (optional) - string
  - *db_parent*: parent directory of database (optional) - string

*notes:* '*qfile*' and '*db*' arguments can be relative to '*query_parent*' and '*db_parent*' (respectively).

- blast_folders( folders=nil, query_parent=nil, db_parent=nil )
  - *folders*: list of folders (optional) - array of strings
  - *query_parent*: parent directory of folders (optional) - string
  - *db_parent*: parent directory of database (optional) - string

*notes:* '*folder*' argument can be relative to '*query_parent*'. All optional parameters must be set in the config.yml file

## Relation with other tools

- [Gene Extractor](https://github.com/averissimo/gene-extractor/): can be used to extract genes from Kegg2 and GenBank using keyword search.
- [ORF-Finder](http://github.com/averissimo/orf_finder): Finds the longest Open Reading Frame from a nucleotide sequence.

## Ackowledgements

This tool was created as a part of [FCT](www.fct.p) grant SFRH/BD/97415/2013 and European Commission research project [BacHBerry](www.bachberry.eu) (FP7- 613793)

[Developer](http://web.tecnico.ulisboa.pt/andre.verissimo/)
