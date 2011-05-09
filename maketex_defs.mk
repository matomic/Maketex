#SHELL    = bash

### Some string for grep
GRPW1   :="LaTeX Warning: There were undefined references.
GRPW1   :=$(GRPW1)|Package natbib Warning: There were undefined citations."
GRPW2   :="LaTeX Warning: Label(s) may have changed. Rerun to get cross-references right."
GRPW3   :="LaTeX Warning: Citation \`[^']*"
GRPBT   :="\.bib[[:space:]]?"
### Some more useful regular expression:
TeXARG  :={[^{}]*}
TeXOPT  :=\(\[[^][]*\]\|\)
TeXPFX  :=^[^%]*\\\\
### System binaries
TEXOPTS := -interaction=nonstopmode
LATEX   := latex
PDFLATEX:= pdflatex
PDFTK   := pdftk
BIBTEX  := bibtex
EPSPDF  := epstopdf

EGREP   := egrep
SED     := sed
# should work with both gawk (preferred) and mawk
AWK     := awk

### code for colorful output
EBLK    :=[1;30m
ERED    :=[1;31m
EGRN    :=[1;32m
EYLW    :=[1;33m
EBLU    :=[1;34m
ERST    :=[0m

### When undefined reference/citations are found, tries to re-bibtex and
#   retex the input file but no more than MAXRPT times.
MAXRPT    =4

### SUPPRESS OUTPUT
NULLOUT  =1> /dev/null
NULLERR  =2> /dev/null
NULLALL  =&> /dev/null

PDFLOG=$(@:%.pdf=%.log)
DVILOG=$(@:%.dvi=%.log)

### Check TeX file for dependency
define echodepfile 
[ $${$1%$2}$2 = $${$1} ] && echo $${$1} && continue
endef
# given tex filename $1, find print its immediate includes
define includedtexs
$(shell [ -f $(1) ] && grep -o "$(TeXPFX)\(include\|input\)$(TeXARG)" $(1) \
	| grep -o "$(TeXARG)" | tr -d "{}" | tr , "\n"                         \
	| while read f; do $(call echodepfile,f,.tex); echo $${f}.tex; done )
endef
define texdeepinclude
$(call includedtexs,$1)\
$(foreach inp,$(call includedtexs,$1),$(call texdeepinclude,$(inp)))
endef
# make list of included bibs
define includedbibs
$(shell echo $(1) > /dev/null; [ -f $(1) ] && grep -o "$(TeXPFX)\(bibliography\)$(TeXARG)" $(1) \
	| grep -o "$(TeXARG)" | tr -d "{}" | tr , "\n"                       \
	| while read f; do $(call echodepfile,f,.bib); echo $${f}.bib; done )
endef
# make list of figures. If no extension is specified, assumes BOTH eps and pdf.
define includedfigs
$(shell [ -f $(1) ] && grep -o "$(TeXPFX)\(includegraphics\)$(TeXOPT)$(TeXARG)" $(1) \
	| grep -o "$(TeXARG)" | tr -d "{}"                                         \
	| while read f; do $(call echodepfile,f,.eps); $(call echodepfile,f,.pdf); \
	$(call echodepfile,f,.jpg); $(call echodepfile,f,.png);                    \
	echo $${f}.eps $${f}.pdf; done )
endef

## Use an external awk script instead, same thing
#define mktexdep
#$(shell [ -f $1 ] && $(AWK) -f mktexdep.awk $1 2> /dev/null)
#endef

### print string using color
# $(call cprintf,"STR",COLOR)
define cprintf
printf "$2$1$(ERST)"
endef

### Using cprintf to announce what's being run
# $(call cprun,COM,ARG1,ARG2)
# Running COM on ARG1 to make ARG2
 
define cprun
printf "Running $(ERED)%12s$(ERST) on $(EGRN)%20s$(ERST) to make $(EBLU)%s$(ERST).\n" "$1" "$(strip $2)" "$(strip $3)"
endef

### analyze tex file for argument to bibtex and run bibtex.
#  if an uncommented \bibliography{AUG} macro is found, print TEXFILEBASENAME.aux
#  else assume using multibib, each \newcites{ARG} gets and aux file with filename ARG.aux
# $(call auxlist foo.tex)
define auxlist
if [ -n "$$($(EGREP) -o "^[^%]*\\\\bibliography{[^{}]*}" $1)" ]; \
then ( echo $(1:.tex=.aux) ); \
else ( $(EGREP) -o "^[^%]*\\newcites{[^{}]*}" $1 | \
  sed 's:.*\\newcites{\([^{}]*\)}:\1:' | \
  tr ',' ' '; ); fi
endef

#### Look for undefined citation ###

# run bibtex on all the necessary files
# $(call runbib,$1)
define runbib
for f in $$($(call auxlist,$1)); do \
printf "aux file:%s\n" $${f}; \
$(call cprun,$(BIBTEX),$${f%.aux},$${f%.aux}.bbl); \
$(BIBTEX) $${f%.aux} $(NULLOUT); done
endef

# run pdflatex
define runpdftex
$(call cprun,$(PDFLATEX),$1,$(subst tex,pdf,$1)); \
$(PDFLATEX) $(TEXOPTS) $1 $(NULLOUT)
endef

# run latex
define runtex
$(call cprun,$(LATEX),$1,$(subst tex,dvi,$1)); \
  $(LATEX) $(TEXOPTS) $1 $(NULLOUT)
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

.SECONDEXPANSION:
# This rule makes pdf from a master file:
#%.pdf : %.tex $$(call mktexdep,$$(subst pdf,tex,$$@))
%.pdf : %.tex $$(value $$(call rmsuffix,$$@)_deps)
	@# print changed dependents
	@printf "+ "; $(call cprintf,$?,$(EBLU)); printf "\n";
	@# Run tex and bibtex if necessary
	@if ( printf "$?" | egrep -q $(GRPBT) ); then \
$(call runpdftex, $<) && $(call runbib, $<); \
fi; \
$(call runpdftex, $<)
	@# Check log for 
	@m=0; while $(EGREP) $(GRPW1) $(PDFLOG) \
&& [ "$$m" -lt $(MAXRPT) ]; do \
( $(EGREP) -o $(GRPW3) $(PDFLOG) | grep -o "[^\`]*$$"; \
$(call runbib, $<) && $(call runpdftex,$<) ); \
m=$$(( m + 1 )); done; # check for undefined
	@m=0; while $(EGREP) $(GRPW2) $(PDFLOG) \
&& [ "$$m" -lt $(MAXRPT) ]; do \
( $(call runpdftex,$<) ); \
m=$$(( m + 1 )); done;

#%.zip : %.tex $$(call mktexdep,$$(subst zip,tex,$$@))
%.zip : %.tex $$(value $$(call rmsuffix,$$@)_deps)
	zip $@ $^

#%.dvi : %.tex $$(call mktexdep,$$(subst pdf,tex,$$@))
%.dvi : %.tex $$(value $$(call rmsuffix,$$@)_deps)
	@printf "+ "; $(call cprintf,$?,$(EBLU)); printf "\n";
	@$(call runtex,$<)
	@if ( printf "$?" | egrep -q $(GRPBT) ); then \
	( $(call runbib, $<) ) && $(call runtex,$<) \
	fi
	@m=0; while $(EGREP) $(GRPW1) $(subst pdf,log,$@) \
	&& [ "$$m" -lt $(MAXRPT) ]; do \
	( ( $(call runbib, $<) ) && $(call runtex,$<) ); \
	m=$$(( m + 1 )); done;
	@m=0; while $(EGREP) $(GRPW2) $(subst pdf,log,$@) \
	&& [ "$$m" -lt $(MAXRPT) ]; do \
	( $(call runtex,$<) ); \
	m=$$(( m + 1 )); done;
