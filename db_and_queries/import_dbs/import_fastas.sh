#!/bin/bash

echo $1

if [ -z $1 ]; then
    arg=nucl
else
  arg=$1
fi

if [ "$arg" = "nucl" ] && [ "$arg" = "prot" ]; then
  echo "Error: ilegal value, expected \'nucl\' or \'prot\', not \'$arg\'"
  exit
fi

echo "converting fasta files to blast db format"
for f in *.fas *.fna *.fasta; do
  filename="${f%.fasta}"
  filename="${filename%.fas}"
  filename="${filename%.fna}"
  if [ "$filename" != "*" ]; then
    echo "Processing $f with output: $filename"
    makeblastdb -in $f -dbtype "$arg" -out "$filename" -title "$filename"
  fi
done

echo "moving all files to ../db"
for f in *.nhr *.nin *.nsq *.nal; do
  filename="${f%.nhr}"
  filename="${filename%.nin}"
  filename="${filename%.nsq}"
  filename="${filename%.nal}"
  #
  if [ "$filename" != "*" ]; then
    echo "mv $f ../db"
    mv $f ../db
  fi
done
