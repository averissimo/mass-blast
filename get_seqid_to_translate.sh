#!/bin/bash

OUT=translate.txt
IN=out/report.csv

echo "" >> translate.txt
awk -F "\t" '{
if ($2 ~ /^[0-9]+$/)
  print "ncbi " $2
else if ($2 ~ /^([a-z]+:|[0-9]+[.])/)
  print "kegg " $2}' $IN | sort | uniq > $OUT
