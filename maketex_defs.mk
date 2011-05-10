#SHELL    = bash

### Some string for grep
GRPW1   :="LaTeX Warning: There were undefined references.
GRPW1   :=$(GRPW1)|Package natbib Warning: There were undefined citations."
GRPW2   :="LaTeX Warning: Label(s) may have changed. Rerun to get cross-references right."
GRPW3   :="LaTeX Warning: Citation \`[^']*"
GRPBT   :=
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

GREP    := grep
EGREP   := $(GREP) -e 
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

############# TeX dependency macros #############
### For each master file BASE.tex, define variables BASE_deps, BASE_texs, BASE_bibs, BASE_figs, BASE_vector, BASE_raster that holds its requisites.
rmsuffix=$(1:%$(suffix $1)=%)
define texallchildren
$1_texs := $(call texdeepinclude,$1)
endef
define texauxiliaries
$(foreach x,$1 $(value $1_texs),
$1_bibs += $(call includedbibs,$x)
$1_figs += $(addprefix $(FIGS_PATH_PREFIX),$(call includedfigs,$x)))
endef
# divide figs further up between vector and raster graphics
define texdeps_all
$1_vector = $(filter %.eps %.pdf,$(value $1_figs))
$1_raster = $(filter %.png %.jpg,$(value $1_figs))
$1_deps   = $(strip $1 $(value $1_texs) $(value $1_bibs) $(value $1_figs))
endef

############# Check TeX file for dependency #############
## shell echo by suffix; if the shell variable ${$1} has suffix $2, print it:
define sh_echo_file_with_suffix
if [[ $${$1%$2}$2 = $${$1} ]]; then echo $${$1}; continue; fi
endef

## $(call define sh_echo_tex_cmd_args,filename,latexcommand,suffix)
## scan file list in $1 for uncommented command \$2[OPTS]{ARGS} for comma
## separated list of file in ARGS
## then, echo ARGS if it already has suffix $3, otherwise ARGS.$3
## $1 is a space separated list of filenames
## $2 is a colon separated list of latex commands
## $3 is a list of suffix to match
## $4 (OPTIONAL) is a default list of suffix to print when all suffix in $3 failed.
TEXCMD_GREP_RE="^[^%]*\\\\\($(subst :,\|,$2)\)\(\|\[[^][]*\]\){[^}{]*}"
define sh_echo_tex_cmd_args
[ -f $(1) ] && grep -o $(TEXCMD_GREP_RE) $(1)                         \
    | grep -o "$(TeXARG)" | tr -d "{}" | tr , "\n" | while read f; do \
    $(foreach s,$3,$(call sh_echo_file_with_suffix,f,.$s);)                \
    $(if $4,$(foreach s,$4,echo $${f}.$s;),$(foreach s,$3,echo $${f}.$s;)) \
    done
endef

## given tex filename $1 print its immediate includes
define includedtexs
$(shell $(call sh_echo_tex_cmd_args,$1,include:input,tex);)
endef
##

## giving a tex filename, print it, the parse and print all child
## tex source recursively.
define texdeepinclude
$(call includedtexs,$1)\
$(foreach inp,$(call includedtexs,$1),$(call texdeepinclude,$(inp)))
endef
##

## make list of included bibs
define includedbibs
$(shell $(call sh_echo_tex_cmd_args,$1,bibliography,bib);)
endef
##

## make list of figures. If no extension is specified, assumes BOTH eps and pdf.
define includedfigs
$(shell $(call sh_echo_tex_cmd_args,$1,includegraphics,jpg png eps pdf,eps pdf);)
endef
##
############# END: Check TeX file for dependency #############

############# BEGIN: Pretty print #############
### print string using color
# $(call cprintf,"STR",COLOR)
define sh_cprintf
printf "$2$1$(ERST)"
endef

### Announce what's being run in color
# $(call sh_cprun,COM,ARG1,ARG2)
# Running COM on ARG1 to make ARG2
define sh_cprun
printf "Running $(ERED)%12s$(ERST) on $(EGRN)%20s$(ERST) to make $(EBLU)%s$(ERST).\n" "$1" "$(strip $2)" "$(strip $3)"
endef
############# END: Pretty print #############

############# BEGIN: LaTeX grind works #############
### analyze tex file for argument to bibtex and run bibtex.
#  if an uncommented \bibliography{AUG} macro is found, print TEXFILEBASENAME.aux
#  else assume using multibib, each \newcites{ARG} gets and aux file with filename ARG.aux
# $(call sh_auxlist foo.tex)
define sh_auxlist
if [ -n "$$($(EGREP) -o "^[^%]*\\\\bibliography{[^{}]*}" $1)" ]; \
then ( echo $(1:.tex=.aux) ); \
else ( $(EGREP) -o "^[^%]*\\newcites{[^{}]*}" $1 | \
  sed 's:.*\\newcites{\([^{}]*\)}:\1:' | \
  tr ',' ' '; ); fi
endef
define sh_auxlist_2
if [[ -n "$(call sh_echo_tex_cmd_args,$1,bibliography,bib)" ]]; then ( echo $(1:.tex=.aux) ); fi
endef

#### Look for undefined citation ###

# run bibtex on all the necessary files
# $(call sh_runbib,$1)
define sh_runbib
for f in $$($(call sh_auxlist,$1)); do \
printf "aux file:%s\n" $${f}; \
$(call sh_cprun,$(BIBTEX),$${f%.aux},$${f%.aux}.bbl); \
$(BIBTEX) $${f%.aux} $(NULLOUT); done
endef

# run pdflatex
define sh_runpdftex
$(call sh_cprun,$(PDFLATEX),$1,$(subst tex,pdf,$1)); \
$(PDFLATEX) $(TEXOPTS) $1 $(NULLOUT); \
$(GREP) "Warning:" $(1:%.tex=%.log) | sed -e 's,^\(.*Warning\),  $(ERED)\1$(ERST),'
endef

# run latex
define sh_runtex
$(call sh_cprun,$(LATEX),$1,$(subst tex,dvi,$1)); \
$(LATEX) $(TEXOPTS) $1 $(NULLOUT); \
$(GREP) "Warning:" $(1:%.tex=%.log) | sed -e 's,^\(.*\):,  $(ERED)\1$(ERST),'
endef

# $(call sh_run_tex, source_file, target_suffix)
define sh_run_tex
$(if $(filter pdf,$2),$(call sh_runpdftex,$1)) \
$(if $(filter dvi,$2),$(call sh_runtex,$1))
endef

#$(call sh_runsed,REGEXP,IN,OUT)
define sh_runsed
$(call sh_cprun,$(SED),$1 $2,$3); \
  $(SED) $1 $2 > $3
endef

# joining two pdfs using pdftk
#define sh_pdfjoin
#$(call sh_cprun,$(PDFTK) join,$2,$1); \
#  $(PDFTK) $2 output $1; \
#  printf "\n"
#endef
define sh_pdfjoin
$(call sh_cprun,$(PDFTK) join,$2,$1); \
  stapler -fq cat $2 $1; \
  printf "\n"
endef
############# END: LaTeX grind works #############

.SECONDEXPANSION:

## That MASTER rule and recipe for doing all the tex, bibtex work!
## $(call recipe_make_from_tex, source_file, target_suffix)
define recipe_make_from_tex
$(if $(filter pdf,$2), tool:=pdftex,  \
	$(if $(filter dvi,$2), tool:=tex, \
		$(error "What the heck is $2?")))
$(1:%.tex=%.$2) : $1 $(filter-out %.eps,$(value $1_deps))
	### list changed requisite:
	@printf "+ $$(EBLU)%s$$(ERST) \n" "$$?"
	### Run $$(tool) and bibtex once:
	@if ( printf "$$?" | $$(GREP) -q "\.bib\s\+" ); then         \
$$(call sh_run_tex, $$<,$2) && $$(call sh_runbib, $$<); fi; \
$$(call sh_run_tex, $$<,$2)
	### repeat $$(tool)/bibtex up to $$(MAXRPT) times or until no more undefined reference warning 
	@m=0; while $$(EGREP) $$(GRPW1) $$(PDFLOG)              \
&& [ "$$$$m" -lt $$(MAXRPT) ]; do                           \
$$(GREP) -o $$(GRPW3) $$(PDFLOG) | grep -o "[^\`]*$$$$";   \
$$(call sh_runbib, $$<) && $$(call sh_run_tex, $$<,$2);     \
m=$$$$(( m + 1 )); done;
	@m=0; while $$(EGREP) $$(GRPW2) $$(PDFLOG)              \
&& [ "$$$$m" -lt $$(MAXRPT) ]; do                           \
$$(call sh_run_tex,$$<,$2) ;                                \
m=$$$$(( m + 1 )); done;
	@echo
endef

define recipe_make_zip_package
$(1:%.tex=%.zip) : $1 $(value $1_deps)
	zip $@ $^
endef

############# Usual rules #############
%.ps : %.dvi
	@dvips $<
