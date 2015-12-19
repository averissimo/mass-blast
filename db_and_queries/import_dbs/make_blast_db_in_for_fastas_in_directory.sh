#!/bin/bash

echo "converting fasta files to blast db format"
for f in *.fasta; do
  filename="${f%.fasta}"
  echo "Processing $f with output: $filename"
  makeblastdb -in $f -dbtype 'nucl' -out "$filename" -title "$filename" 
done

echo "moving all files to ../db"
mv *.nhr *.nin *.nsq *nal ../db
