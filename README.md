# djvu2pdf
Relatively small script that does most of what you want to do for batch djvu -> pdf conversion on Linux.

Made because none of the djvu converters are maintained, or they explode filesize massively.

# Usage

Call with

```find . -iname "*.djvu" -type f -printf '"%p"\n' | xargs -IF -P6 ~/Downloads/djvu2pdf.sh F```

By default it recognises english and russian books. You can instead specify language

```djvu2pdf.sh F eng```

and that will force a certain language upon all files. Without forcing a language, it won't process files that have no ocr in them.

If you want to enforce monochrome encoding, which will drastically decrease resultant filesize(with colors in worst case you'll get ~100mb on 600 page book), supply 3rd argument

```djvu2pdf.sh F auto 1```

"auto" here restores the automatic language recognition.

# Dependencies

Expects OcrMyPdf and PyMuPDF installed in ~/.local
^install with ```pip install ocrmypdf PyMuPDF --user```

Expects all of OcrMyPdf dependencies(including optional) and MuPdf

Expects to find tiff, djvu, poppler, imagemagick and texlive-latex installed on your system
