MassBLAST
==========

Perform BLAST queries from multiple files against different databases at once

**We recommend using a packaged release of MassBlast available [at this link](https://github.com/averissimo/mass-blast/releases)**. The only requirement is to have BLAST+ installed. See all the information in the section below.

# Install and usage (from a release)

Pre-packaged releases of MassBlast are available at github, [download here](https://github.com/averissimo/mass-blast/releases) and support:
  - Linux 32/64-bit
  - Mac OSX (recent versions)
  - Windowns (the binaries are 32-bits, due to our packaging tool that includes ruby and other dependencies)

Requirements:
- BLAST+ installed
  -  [link to download latest version](https://blast.ncbi.nlm.nih.gov/Blast.cgi?PAGE_TYPE=BlastDocs&DOC_TYPE=Download)
    - note for Windows users:
      1. Can only install 32-bit version of BLSAT+ (latest win32 version is 2.2.30 that can be [downloaded here](ftp://ftp.ncbi.nlm.nih.gov/blast/executables/blast+/2.2.30/))
      2. If it gives an error, please delete `ncbi.ini` located at a subdirectory at the `AppData` folder, if problem persists, submit an issue.

Default options can be changed at user.yml, check user.yml.example for more information (manual soon).

## How to use it?

- Place fasta files with queries at `db_and_queries/queries` folder.
- Place blast databases at `db_and_queries/db` folder.
  - Check "How to setup a Blast database for a transcriptome" below for more information on creating a Blast database.
- Edit user.yml file to change options and BLAST engine to be used.
- run mass-blast script (either double click it on Windows or as a command in the command line.

# Install and usage (from source code)

We do not recommend installing from source unless you plan to develop MassBlast further. The package available already has all dependencies pre-packaged and is ready to be used.

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

  - nucleotides database

    $ makeblastdb -in &lt;filename&gt; -dbtype nucl -out "&lt;blast_db_new_name&gt;" -title "&lt;blast_db_new_name&gt;"

  - protein database

    $ makeblastdb -in &lt;filename&gt; -dbtype nucl -out "&lt;blast_db_new_name&gt;" -title "&lt;blast_db_new_name&gt;"

*note:* do to not use spaces in the &lt;blast db new name&gt;

### Quickly setup databases in Linux and Mac OSX

In Linux and OSX you can place the fasta files in db_and_queries/import_dbs directory and run the import_fastas.sh script

    $ cd db_and_queries/import_dbs
    $ sh import_fastas.sh [nucl|prot]

In Windows run the import_fastas.bat script

    $ cd db_and_queries/import_dbs
    $ import_fastas.bat [nucl|prot]

## Relation with other tools

- [Gene Extractor](https://github.com/averissimo/gene-extractor/): can be used to extract genes from Kegg2 and GenBank using keyword search.
- [ORF-Finder](http://github.com/averissimo/orf_finder): Finds the longest Open Reading Frame from a nucleotide sequence.
- [MassBlast package bundler](https://github.com/averissimo/app-mass-blast): Creates a package that can be easily used in all main Operating Systems without having to install Ruby and any Ruby dependecies.

## Ackowledgements

This tool was created as a part of [FCT](www.fct.p) grant SFRH/BD/97415/2013 and European Commission research project [BacHBerry](www.bachberry.eu) (FP7- 613793)

[Developer](http://web.tecnico.ulisboa.pt/andre.verissimo/)
