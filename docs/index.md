MassBLAST
==========

Perform BLAST queries from multiple files against different databases at once.

## Install

The latest release can be [downloaded here](https://github.com/averissimo/mass-blast/releases/latest).

It already has most dependencies, **it only requires BLAST+ to be installed before running**: [link to download latest version](https://blast.ncbi.nlm.nih.gov/Blast.cgi?PAGE_TYPE=BlastDocs&DOC_TYPE=Download)

Important note for Windows users:
  1. Can only install 32-bit version of BLSAT+ (latest win32 version is 2.2.30 that can be [downloaded here](ftp://ftp.ncbi.nlm.nih.gov/blast/executables/blast+/2.2.30/))
  2. If it gives an error, please delete `ncbi.ini` located at a subdirectory at the `AppData` folder, if problem persists, submit an issue.

### How to use it?

Options can be configurable at `user.yml`, check `user.yml.example` for more information.

- Place fasta files with queries at `db_and_queries/queries` folder.
  - You can have as many files as needed, see below for an example of a nucleotide query
- Place blast databases at `db_and_queries/db` folder.
  - Check "How to setup a Blast database for a transcriptome" below for more information on creating a Blast database.
- Edit user.yml file to change options and BLAST engine to be used.
- run mass-blast script *(either double click it on Windows or as a command in the command line.*

Example of a nucleotide query file that could be placed in `db_and_queries/queries` folder:

```
>Example01
attgggaatttactgcaactcaaggagaagaaaccctaccagacttttacaaggtgggct
gaggagt
>Example03
attgggaatttactgcaactcaaggagaagaaaccctaccagactttt
>Example02
attgggaatttactgcaactcaaggagaagaaaccctaccagacttttacaaggtgggct
gaggagtatttactgcaactcaaggagaagaaaccctaccagacttttacaaggtggtgg
gcaactcaagcaactcaagcaactcaagcaactcaa
```

### Type of blast implemented

- Blastn
- TBlastn
- TBlastx


### How to setup a Blast database for a transcriptome

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

#### Quickly setup databases

Place the fasta files for the database in db_and_queries/import_dbs directory and run the appropriate script.

You also need to say if it is a nucleotide or protein-based fasta file.

For Linux and Mac OS X run the `import_fastas.sh` script

    $ cd db_and_queries/import_dbs
    # for nucleotide
    $ sh import_fastas.sh nucl
    # for protein
    $ sh import_fastas.sh prot

For Windows run the `import_fastas.bat` script

    $ cd db_and_queries/import_dbs
    # for nucleotide
    $ import_fastas.bat nucl
    # for protein
    $ import_fastas.bat prot

### Relation with other tools

- [Gene Extractor](https://github.com/averissimo/gene-extractor/): can be used to extract genes from Kegg2 and GenBank using keyword search.
- [ORF-Finder](http://github.com/averissimo/orf_finder): Finds the longest Open Reading Frame from a nucleotide sequence.
- [MassBlast package bundler](https://github.com/averissimo/app-mass-blast): Creates a package that can be easily used in all main Operating Systems without having to install Ruby and any Ruby dependecies.

## Ackowledgements

This tool was created as a part of [FCT](www.fct.p) grant SFRH/BD/97415/2013 and European Commission research project [BacHBerry](www.bachberry.eu) (FP7- 613793)

[Developer](http://web.tecnico.ulisboa.pt/andre.verissimo/)
