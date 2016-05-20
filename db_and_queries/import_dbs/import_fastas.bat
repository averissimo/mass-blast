@echo off

if "%1" == "" (
SET arg=nucl

echo "Creating databases with default argument of '%arg%', if files have protein sequence use:"
echo "  import_fastas.bat prot"

) else (
SET arg=%1
echo "Creating databases for %arg%."
)

if NOT "%arg%" == "nucl" (
	if NOT "%arg%" == "prot" (
		echo "Error: ilegal value, expected 'nucl' or 'prot', not '%arg%'"
    echo ""
    echo "Usage: (by default nucl)"
    echo "  import_fastas.bat [nucl|prot]"
	)
) ELSE (

	for /r %%i in (*.fna *.fas*) do @makeblastdb -in %%i -dbtype "%arg%" -out "%%~ni" -title "%%~ni"

	echo "moving all files to ../db"
	move *.nhr ../db
	move *.nin ../db
	move *.nsq ../db
	move *.nal ../db
	move *.phr ../db
	move *.pin ../db
	move *.psq ../db
	move *.pal ../db
)
