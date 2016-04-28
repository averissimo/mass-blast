@echo off

if [%1] == [] (
%1 = nucl
)

if NOT "%1" == "nucl" if NOT "%1" == "prot" (
echo "Error: ilegal value, expected 'nucl' or 'prot', not '%1%'"
exit
)

for /r %%i in (*.fasta *.fna *.fas) do @makeblastdb -in %%i -dbtype "%1" -out "%%~ni" -title "%%~ni"

echo "moving all files to ../db"
move *.nhr ../db
move *.nin ../db
move *.nsq ../db
move *.nal ../db
move *.phr ../db
move *.pin ../db
move *.psq ../db
move *.pal ../db
