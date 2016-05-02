#!/bin/bash

loc="../db"
arg="nucl"
count=0

while [ $# -gt 1 ]
do
key="$1"

case $key in
    -t|--type)
    arg="$2"
    shift # past argument
    ;;
    -d|--dest)
    loc="$2"
    shift # past argument
    ;;
    *)
    # unknown option
    break
    ;;
esac
shift # past argument
done

if [ -z "$@" ]; then
  files="*.fas *.fna *.fasta"
else
  files=$*
fi

if [ "$arg" != "nucl" ] && [ "$arg" != "prot" ]; then
  echo "Error: ilegal value, expected 'nucl' or 'prot', not '$arg'"
  exit
fi

echo "Converting fasta files to blast db format"
for f in $files
do
  if [ -f $f ]; then
    filename=$(basename "$f")
    # extension="${filename##*.}"
    filename="${filename%.*}"
    echo "Processing $f with output: $filename"
    makeblastdb -in $f -dbtype "$arg" -out "$filename" -title "$filename"
    count=$((count + 1))
  fi
done

if [ $count -gt 0 ]; then
  echo "moving all files to ../db"
  for f in *.nhr *.nin *.nsq *.nal *.phr *.pin *.psq *.pal; do
    filename="${f%.nhr}"
    filename="${filename%.nin}"
    filename="${filename%.nsq}"
    filename="${filename%.nal}"
    filename="${filename%.pin}"
    filename="${filename%.psq}"
    filename="${filename%.pal}"
    #
    if [ "$filename" != "*" ]; then
      echo "mv $f $loc"
      mv $f $loc
    fi
  done
else
  echo "No files to process in: $files"
fi
