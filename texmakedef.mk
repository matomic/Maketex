#SHELL    = bash

### Identify LaTeX mater file by \documentclass
MASTER   = "^\\\\documentclass"

### Some string for grep
GRPW1   :="LaTeX Warning: There were undefined references.
GRPW1   :=$(GRPW1)|Package natbib Warning: There were undefined citations."
GRPW2   :="LaTeX Warning: Label(s) may have changed. Rerun to get cross-references right."
GRPBT   :="\.bib[[:space:]]?"

### System binaries
TEXOPTS  = -interaction=nonstopmode
LATEX    = latex
PDFLATEX = pdflatex
PDFTK    = pdftk
BIBTEX   = bibtex
EPSPDF   = epstopdf

EGREP    = egrep
SED      = sed
# should work with both gawk (preferred) and mawk
AWK      = awk

### code for colorful output
EBLK     =[1;30m
ERED     =[1;31m
EGRN     =[1;32m
EYLW     =[1;33m
EBLU     =[1;34m
ERST     =[0m

### list of files for included graphics
SRCFIG  := $(foreach tex, $(SRCTEX), $(call mktexdep,$(tex)))
SRCFIG  := $(filter-out %.tex,$(SRCFIG))
SRCFIG  := $(filter-out %.bib,$(SRCFIG))

### When undefined reference/citations are found, tries to re-bibtex and
#   retex the input file but no more than RETEX times.
RETEX    =3 

### SUPPRESS OUTPUT
NULLOUT  =1> /dev/null
NULLERR  =2> /dev/null
NULLALL  =&> /dev/null

### Check TeX file for dependency
##  use an awk script that scans for \input{}, \include{}, \includegraphics[]{}, \bibliography{}
# define mktexdep
# [ -f $1 ] && $(AWK) "
# function print_file(fs) { \
#   system(sprintf(\"for f in %s; do printf \\\"\$$f \\\"; done\", fs)); }
# function print_eps(fs) { \
#   system(sprintf(\"f=\\\"%s\\\"; printf \\\"\$$f \$${f%%eps}pdf \\\"\",fs)); }
# function add_file(f) { \
#   if (system(\"test -f \"f) == 0 ) {ARGV[ARGC]=f; ARGC++;} }
# FNR==1 { printf(\"%s \",FILENAME) } 
# /^[^%]*\\\\inpu(t|t\[[^{}]*\]){[^{}]*}/ { \
#   split(\$$0,A,/(.*\\\\inpu(t|t\[[^{}]*\]){|})/);\
#   add_file(A[2]); add_file(A[2]\".tex\"); }
# /^[^%]*\\\\includ(e|e\[[^{}]*\]){[^{}]*}/ { \
#   split(\$$0,A,/(.*\\\\includ(e|e\[[^{}]*\]){|})/); \
#   add_file(A[2]); add_file(A[2]\".tex\"); }
# /^[^%]*\\\\documentclas(s|s\[[^{}]*\]){[^{}]*}/ { \
#   split(\$$0,A,/(.*\\\\documentclas(s|s\[[^{}]*\]){|})/); \
#   print_file(A[2]); print_file(A[2]\".cls\"); }
# /^[^%]*\\\\includegraphic(s|s\[[^{}]*\]){[^{}]*}/ { \
#   split(\$$0,A,/(.*\\\\includegraphic(s|s\[[^{}]*\]){|})/); \
#   print_file(A[2]\" \"A[2]\".png \" A[2]\".jpg \" A[2]\".jpeg\"); \
#   print_eps(A[2]\".eps\"); }
# /^[^%]*\\\\bibliographystyle[^{}]*{[^{}]*}/ { \
#   split(\$$0,A,/(.*\\\\bibliographystyle[^{}]*{|})/); \
#   print_file(A[2]); print_file(A[2]\".bst\"); }
# /^[^%]*\\\\bibliography[^{}]*{[^{}]*}/ { \
#   split(\$$0,A,/(.*\\\\bibliography[^{}]*{|})/); \
#   print(A[2]\".bib\"); }
# END{printf\"\n\"}" $1
# endef

## Use an external awk script instead, same thing
define mktexdep
[ -f $1 ] && $(AWK) -f mktexdep.awk $1 2> /dev/null
endef

### print string using color
# $(call cprintf,"STR",COLOR)
define cprintf
printf "$2$1$(ERST)"
endef

### Using cprintf to announce what's being run
# $(call cprun,COM,ARG1,ARG2)
# Running COM on ARG1 to make ARG2
 
define cprun
printf "Running "; $(call cprintf,$1,$(ERED)); \
  printf " on "; $(call cprintf,$2,$(EGRN)); \
  printf " to make "; $(call cprintf,$3,$(EBLU)); \
  printf "\n"
endef

### analyze tex file for argument to bibtex and run bibtex.
#   Works for multibib case.
# $(call auxlist foo.tex)
define auxlist
[ -n "$$($(EGREP) -o "^[^%]*\\\\bibliography{[^{}]*}" $1)" ] && \
  ( echo $(1:.tex=.aux) ) || \
  ( $(EGREP) -o "^[^%]*\\newcites{[^{}]*}" $1 | \
  sed 's:.*\\newcites{\([^{}]*\)}:\1:' | \
  tr ',' ' '; )
endef

# run bibtex on all the necessary files
# $(call runbib,$1)
define runbib
for f in $$($(call auxlist,$1)); do \
  $(call cprun,$(BIBTEX),$${f%.aux},$${f%.aux}.bbl); \
  $(BIBTEX) $${f%.aux} $(NULLOUT); \
done;
endef

# run pdflatex
define runpdftex
$(call cprun,$(PDFLATEX),$1,$(subst tex,pdf,$1)); \
  $(PDFLATEX) $(TEXOPTS) $1 $(NULLOUT);
endef

# run latex
define runtex
$(call cprun,$(LATEX),$1,$(subst tex,dvi,$1)); \
  $(LATEX) $(TEXOPTS) $1 $(NULLOUT);
endef

#$(call runsed,REGEXP,IN,OUT)
define runsed
$(call cprun,$(SED),$1 $2,$3); \
  $(SED) $1 $2 > $3
endef

# joining two pdfs using pdftk
#define pdfjoin
#$(call cprun,$(PDFTK) join,$2,$1); \
#  $(PDFTK) $2 output $1; \
#  printf "\n"
#endef
define pdfjoin
$(call cprun,$(PDFTK) join,$2,$1); \
  stapler -fq cat $2 $1; \
  printf "\n"
endef

# This rule makes pdf from a master file:
.SECONDEXPANSION:
#%.pdf : %.eps
#	@[ -h $@ ] || ( $(call cprun,$(EPSPDF),$^,$@); $(EPSPDF) $< );

%.pdf : %.tex $$(shell $$(call mktexdep,$$(subst pdf,tex,$$@)))
	@printf "+ "; $(call cprintf,$?,$(EBLU)); printf "\n";
	@$(call runpdftex,$<)
	@if ( printf "$?" | egrep -q $(GRPBT) ); then \
		( $(call runbib, $<) ) && $(call runpdftex,$<) \
		fi
	@m=0; while $(EGREP) $(GRPW1) $(subst pdf,log,$@) \
		&& [ "$$m" -lt $(RETEX) ]; do \
		( ( $(call runbib, $<) ) && $(call runpdftex,$<) ); \
		m=$$(( m + 1 )); done;
	@m=0; while $(EGREP) $(GRPW2) $(subst pdf,log,$@) \
		&& [ "$$m" -lt $(RETEX) ]; do \
		( $(call runpdftex,$<) ); \
		m=$$(( m + 1 )); done;

%.zip : %.tex $$(shell $$(call mktexdep,$$(subst zip,tex,$$@)))
	zip $@ $^

%.dvi : %.tex $$(shell $$(call mktexdep,$$(subst pdf,tex,$$@)))
	@printf "+ "; $(call cprintf,$?,$(EBLU)); printf "\n";
	@$(call runtex,$<)
	@if ( printf "$?" | egrep -q $(GRPBT) ); then \
		( $(call runbib, $<) ) && $(call runtex,$<) \
		fi
	@m=0; while $(EGREP) $(GRPW1) $(subst pdf,log,$@) \
		&& [ "$$m" -lt $(RETEX) ]; do \
		( ( $(call runbib, $<) ) && $(call runtex,$<) ); \
		m=$$(( m + 1 )); done;
	@m=0; while $(EGREP) $(GRPW2) $(subst pdf,log,$@) \
		&& [ "$$m" -lt $(RETEX) ]; do \
		( $(call runtex,$<) ); \
		m=$$(( m + 1 )); done;
