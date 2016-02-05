MassBLAST
==========

Library to query multiple files against many databases

# Install and usage (from a release)

Pre-packaged releases of MassBlast are available at github, [download here](https://github.com/averissimo/mass-blast/releases) and support:
  - Linux 32/64-bit
  - Mac OSX (recent versions)
  - Windowns (althought the binaries are 32-bits, due to our packaging tool)

Requirements:
- Blast+ installed
  -  [link to download latest version](https://blast.ncbi.nlm.nih.gov/Blast.cgi?PAGE_TYPE=BlastDocs&DOC_TYPE=Download)
    - note for Windows users:
      1. Can only install 32-bit version of Blast+ (latest win32 version is 2.2.30 that can be [downloaded here](ftp://ftp.ncbi.nlm.nih.gov/blast/executables/blast+/2.2.30/))
      2. If it gives an error, please delete ncbi.ini located at a subdirectory at the AppData folder, if problem persists, submit an issue.

Default options can be changed at user.yml, check user.yml.example for more information (manual soon).

## How to use it?

- Place fasta files with queries at `db_and_queries/queries` folder.
- Place blast databases at `db_and_queries/db` folder.
  - Check "How to setup a Blast database for a transcriptome" below for more information on creating a Blast database.
- run mass-blast script (either double click it on Windows or as a command in the command line.

# Install and usage (from source code)

Requirements:
- Ruby interpreter
- Bundler gem
- rub `bundle install` at root directory
- Options are configurable via `config/user.yml` file
  - Change 'db_parent' and 'query_parent' to specify the parent directories for blast databases and queries
  - Change 'dbs' and 'folder_queries' to specify the databases that should be used and which query folders should be crawled

  $ ruby script.rb

## External data

The test blast database and the taxonomy database are not kept in the git tree anymore, to get this auxiliary data run the command below or call mass-blast via script.rb

    $ rake bootstrap.rb

If you need to include it on your code use:

    require_relative 'src/download'

    ExternalData.download(path_to_db_parent)

## How to test it

    $  rake spec

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

## How to setup a Blast database for a transcriptome

Using makeblastdb command that comes bundled with Blast+

- Open the command line in your operating system
- Navigate to directory
- Go to directory that has the fasta file with the assembly
- Run makeblastdb command in that directory

    $ makeblastdb -in &lt;filename&gt; -dbtype nucl -out "&lt;blast db new name&gt;" -title "&lt;blast db new name&gt;"

*note:* try to not use spaces in the &lt;blast db new name&gt;

### Quickly setup databases in Linux and Mac OSX

In Linux and OSX you can place the fasta files in db_and_queries/import_dbs directory and run the make_blast_db_in_for_fastas_in_directory.sh script

    $ cd db_and_queries/import_dbs
    $ sh make_blast_db_in_for_fastas_in_directory.sh

## Relation with other tools

- [Gene Extractor](https://github.com/averissimo/gene-extractor/): can be used to extract genes from Kegg2 and GenBank using keyword search.
- [ORF-Finder](http://github.com/averissimo/orf_finder): Finds the longest Open Reading Frame from a nucleotide sequence.
- [MassBlast package bundler](https://github.com/averissimo/app-mass-blast): Creates a package that can be easily used in all main Operating Systems without having to install Ruby and any Ruby dependecies.

## Ackowledgements

This tool was created as a part of [FCT](www.fct.p) grant SFRH/BD/97415/2013 and European Commission research project [BacHBerry](www.bachberry.eu) (FP7- 613793)

[Developer](http://web.tecnico.ulisboa.pt/andre.verissimo/)
