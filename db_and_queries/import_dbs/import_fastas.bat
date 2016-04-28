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
move *.nhr *.nin *.nsq *.nal ../db
move *.phr *.pin *.psq *.pal ../db
