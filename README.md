`maketex` : Makefile and auxiliary scripts for automated LaTeX processing

### FEATURES:
* Automatic identify master .tex file
* Use RE to automatically identify included tex, bib, and figs
* Use RE to automatically identify citation table and partial .bib file from a master file
* Tries to be as self-contained with simple sh tool (greg, sed, awk) as possible

### SOME USAGES:
* Add the following line to the beginning of your Makefile (see Makefile_tex for example):
```make
include maketex_defs.mk
all : $(TARGET_PDF) $(TARGET_DVI) $(TARGET_PS)
```

* To make all master files, add to Make file:

        make all

* To make a specific pdf (or dvi or ps) file:

        make maintex.pdf

* To see dependency information run:

        make depinfo

* To see citation information run:

        make citeinfo

### ADVANCED USAGE:

1. Specify `FIGS_PATH_PREFIX` if figures are located in another location, e.g.: `FIGS_PATH_PREFIX='figures/' make`

2. Specify `MAINBIB` environment variable to automatic generation of partial bib list. Suppose `main.bib` is a large BibTeX database that has a lot of entries, only a handful of which is cited in a particular .tex file.  In the tex file, you can have the line: `\bibliography{partial}` then run `MAINBIB='main.bib' make partial.bib` to generate a bibfile that contains only those entries from `main.bib` that the including tex file cites.

### WHAT WORKS AND HOW IT WORKS:
Including `maketex_defs.mk` gives user access to the following MACROS:

1. `MASTER_TEX`: List of master tex file in current directory. They are `*.tex` file in the current directory that contains the command `\documentclass[OPTS]{CLS}`.

2. `TARGET_PDF TARGET_DVI TARGET_PS`: LaTeX target of various format. They are `$(MASTER_TEX)` files with substituted suffix and the following phony targets:
     - `depinfo` Display all dependency information under current directory
     - `citeinfo` Display all citation information under current directory

Each item in `TARGET_{PDF,DVI,PS}` are also Make target that when their prerequisites are modified, make will

1. Run `latex`/`pdflatex` and `bibtex` on the corresponding master tex file

2. Scan the output log for warning regarding missing label/citation and repeat step 1 upto 4 times.

### WHAT DOESN'T WORK (TO DO LIST)
* There cannot be two master tex file that cites the same partial list generated using `MAINBIB` environment variable.  One of them will overwrite the other!

* Currently only a single static `\graphicspath{%}` is allowed and must be specified manually.
