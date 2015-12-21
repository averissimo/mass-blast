#!/bin/bash

echo "converting fasta files to blast db format"
for f in *.fas *.fna *.fasta; do
  filename="${f%.fasta}"
  filename="${filename%.fas}"
  filename="${filename%.fna}"
  echo "Processing $f with output: $filename"
  makeblastdb -in $f -dbtype 'nucl' -out "$filename" -title "$filename" 
done

echo "moving all files to ../db"
mv *.nhr *.nin *.nsq *nal ../db
