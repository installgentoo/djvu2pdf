#!/bin/bash
count_cyrillic() {
echo "$1" | grep -oP "[\p{Cyrillic}]" | wc -l
}

count_latin() {
echo "$1" | grep -oP "[\p{Latin}]" | wc -l
}

detect_language() {
local cyrillic_count="$(count_cyrillic "$1")"
local latin_count="$(count_latin "$1")"

if (( $cyrillic_count > $latin_count )); then
	echo "rus"
else
	echo "eng"
fi
}

_ARG1="$(realpath "$1")"

NAME="${_ARG1##*/}"
PATHNAME="${_ARG1%/*}"
NAME="$(echo "${NAME%.*}" | head -c 210)"

_T_NEWNAME="$NAME".pdf
NEWNAME="$PATHNAME/$NAME"_OMP_REOCRD_14_2_1_.pdf

_TMPNAME="$(basename "${_ARG1%/*}" | head -c 80)"
_BASE="$(basename "$_ARG1" | head -c 110)"
_UUID=$(uuidgen -t)
TMPNAME="/tmp/$_TMPNAME$_BASE$_UUID"

NUM_PAGES=$(djvused -e 'n' "$_ARG1")

echo "nump $NUM_PAGES"

_LANG="eng"
if [ -z "$2" ] || [[ "$2" == "auto" ]]; then
_WORDS="$(djvutxt "$_ARG1")"
NWORDS="$(echo "$_WORDS" | grep -oP "[\p{L}]" | wc -l)"
echo "$NWORDS"
if (( `echo "$NWORDS / $NUM_PAGES > 50" | bc -l` )); then
	_LANG="$(detect_language "$_WORDS")"
else
	echo "$_ARG1         -UNKNOWN LANG" >> /tmp/__LOG_ocrmydjvu
	NEWNAME="$PATHNAME/$NAME"_OMP_REOCRD_14_2_1_UNKN.pdf
	exit 0											                  #comment to force ENG on indeterminate files
fi
else
_LANG="$2"
fi

mkdir -p "$TMPNAME"
cd "$TMPNAME"

echo "$_LANG, book - $_ARG1"

export PATH="~/.local/bin:$PATH"

for (( iPAGE=1; iPAGE<=NUM_PAGES; iPAGE++ )); do
	_PP=""
    _PG="p$(printf "%05d" "$iPAGE")"
    _PT="$_PG.tiff"
    _PDF="$_PG.pdf"
    OPDF="o$_PDF"

	ddjvu -scale=300 -format=tiff -page="$iPAGE" "$_ARG1" "$_PT"
	if [ $? -ne 0 ]; then
		echo "$_ARG1                          -ddjvu failed for page $iPAGE, skipping page" >> /tmp/__LOG_ocrmydjvu
		continue
	fi

	echo "start $iPAGE"
	if [ ! -f "$_PT" ]; then
		exit 1
		echo "ddjvu somehow failed"
	fi
    
    _PGINFO="$(djvused -e "select $iPAGE; dump" "$_ARG1")"
if echo "$_PGINFO" | grep -q "b&w" || ! echo "$_PGINFO" | grep -q "color" || [ ! -z "$3" ] ; then
    _PP="$_PG.png"
    convert "$_PT" -background white -alpha remove -strip -resize x3072\> -threshold 50% -monochrome -format png "$_PP"
    
LATEX_DOC="\\documentclass{article}
\\usepackage{graphicx}
\\usepackage[margin=0cm]{geometry}
\\pagestyle{empty}
\\begin{document}
\\includegraphics[width=\textwidth,height=\textheight,keepaspectratio]{{$_PP}}
\\end{document}"

	_PL="$_PG.tex"
	echo "$LATEX_DOC" > "$_PL"
	pdflatex -interaction=nonstopmode "$_PL" > /dev/null
	
	ocrmypdf -l "$_LANG" --optimize 3 --jbig2-lossy --force-ocr --rotate-pages --clean "$_PDF" "$OPDF"
	mv -f "$OPDF" "$_PDF"
	
    echo "done b&w $iPAGE"

	rm -f "$_PL" "$_PG".log "$_PG".aux
else
    _PP="$_PG.jpeg"
    tiff2pdf -m 0 -d "$_PT" -o "$_PDF"

    convert "$_PT" -background white -alpha remove -strip -resize x1700\> -format jpg -quality 40 -interlace plane "$_PP"
    
	ocrmypdf -l "$_LANG" --force-ocr --clean "$_PDF" "$OPDF"
	rm -f "$_PDF"
	
	echo "done col $iPAGE"

python3 - "$OPDF" "$_PP" "$_PDF" <<END
import sys
import fitz

if len(sys.argv) != 4:
    print("Usage: script.py original_pdf image out_pdf")
    sys.exit(1)
    
pdf_path = sys.argv[1]
image_path = sys.argv[2]
out_path = sys.argv[3]

doc = fitz.open(pdf_path)
pix = fitz.Pixmap(image_path)

for img in doc.get_page_images(0):
	xref = img[0]
	page = doc[0]
	page.replace_image(xref, filename=image_path)

doc.save(out_path, garbage=4, deflate=True)    
END
    
	rm -f "$OPDF"
fi

    rm -f "$_PT" "$_PP"
done

pdfunite *.pdf "$_T_NEWNAME"

if [ -f "$_T_NEWNAME" ]; then
mv -f "$_T_NEWNAME" "$NEWNAME" && rm -f "$_ARG1"
else
echo "$_ARG1         -NO FILE GENERATED" >> /tmp/__LOG_ocrmydjvu
fi

rm -f p*.pdf
cd /
rm -df "$TMPNAME"

# run like
#    find . -iname "*.djvu" -type f -printf '"%p"\n' | xargs -IF -P6 ~/Downloads/djvu2pdf.sh F
