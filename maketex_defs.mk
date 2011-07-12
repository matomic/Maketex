#SHELL    = bash

### Some string for grep
GRPW1   :="LaTeX Warning: There were undefined references.\
\|Package natbib Warning: There were undefined citations."
GRPW2   :="LaTeX Warning: Label(s) may have changed. Rerun to get cross-references right."
GRPW3   :="Warning: Citation \`[^']*"

### System binaries
TEXOPTS := -interaction=nonstopmode
LATEX   := latex
PDFLATEX:= pdflatex
DVIPS   := dvips
PDFTK   := pdftk
BIBTEX  := bibtex
EPSPDF  := epstopdf

GREP    := grep
EGREP   := $(GREP) -E 
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
NULLOUT :=1> /dev/null
NULLERR :=2> /dev/null
NULLALL :=>& /dev/null

PDFLOG=$(@:%.pdf=%.log)
DVILOG=$(@:%.dvi=%.log)

### Some more useful regular expression:
re_nobrace :=[^}{\#]*
re_nosqrbr :=[^][]*
re_texcmd  :=^[^%]*\\\\
re_texarg  :={$(re_nobrace)}
re_texopt  :=\[$(re_nosqrbr)\]

############# TeX dependency macros #############
rmsuffix=$(1:%$(suffix $1)=%)
## $(call macro_tex_descendants, tex_file)
## Generate macro to hold list of \input and \include children of tex_file
## tex_file_texs = {\input{*} and \include{*} items in tex_file}
define macro_tex_descendants
$1_texs := $(call tex_all_descendants,$1)
endef

## $(call macro_tex_auxiliaries, tex_file)
## Generates macro to hold list of auxiliary files for tex_file
## tex_file_bibs = {bibtex files used in tex_file and its children}
## tex_file_figs = {figures included in tex_file and its children}
define macro_tex_auxiliaries
$(foreach x,$1 $(value $1_texs),
$1_bibs += $(call includedbibs,$x) $(MAINBIB)
$1_figs += $(addprefix $(FIGS_PATH_PREFIX)$(if $(FIGS_PATH_PREFIX),/), \
	$(call includedfigs,$x)))
endef

## $(call macro_tex_depinfo, tex_files)
## for each foo.tex in tex_files, evaluates the following macros:
## foo.tex_texs : recursive list of included tex files.
## foo.tex_bibs : recursive list of bib file used.
## foo.tex_figs : resursive list of figs (eps, pdf, jpg, png) included
## foo.tex_pdfdeps : filtered deps for pdflatex
## foo.tex_dvideps : filtered deps for latex
## foo.tex_deps : all of above
define macro_tex_depinfo
$(foreach x,$(filter %.tex,$1), \
	$(eval $(call macro_tex_descendants,$x)) \
	$(eval $(call macro_tex_auxiliaries,$x)) \
	$(eval $x_pdfdeps = $(strip $x $(value $x_texs) $(value $x_bibs)   \
							$(filter-out %.eps,$(value $x_figs))))     \
	$(eval $x_dvideps = $(strip $x $(value $x_texs) $(value $x_bibs)   \
							$(filter %.eps,$(value $x_figs))))         \
	$(eval $x_deps = $(strip $x $(value $x_texs) $(value $x_bibs)      \
							$(value $x_figs)))   \
	$(eval all_bibs += $(sort $(value $x_bibs))) \
	$(eval all_texs += $(sort $(value $x_texs))))
endef
############# LaTeX/BibTeX citation parsing functions #############
# awk binary and regular expression used in awk:
awk_re_bib_prem = /^@(STRING)\s*{/
awk_re_bib_item = /^@(ARTICLE|BOOK|INBOOK|UNPUBLISHED)\s*{/
# awk function to count braces:
awk_fnc_pcntbrc = function foo() { print; lb+=split(\$$0,a,/{/); rb+=split(\$$0,a,/}/); }

########
## $(call sh_cite_keys_in_tex, tex_source)
## print list of cited bibliographic key in tex_source
define sh_cite_keys_in_tex
$(foreach f,$1, \
	[ -f "$f" ] && grep -o "\\\\\(nocite\|cite\|onlinecite\)$(re_texarg)" $1 \
	| grep -o "{$(re_nobrace)}$$" | grep -o "$(re_nobrace)" | tr "," " ";) \
echo > /dev/null
endef

########
## $(call macro_tex_cite_keys, tex_source)
## Assign a macro for list of cited bibliographic key in tex_source
define macro_tex_cite_key
$1_cites := $(sort $(shell $(call sh_cite_keys_in_tex,$1)))
endef

define macro_tex_citeinfo
$(foreach x,$1,$(eval $(call macro_tex_cite_key,$x)) \
	$(foreach y,$(value $x_texs), $(eval $(call macro_tex_cite_key,$y))))
endef

########
## $(call sh_get_bibitem_by_key, key, master_bib)
## Retrieve bibitem with key from master_bib
define sh_get_bibitem_by_key
$(AWK) "BEGIN {FS=\"{\"} $(awk_fnc_pcntbrc) \
	toupper(\$$0)  ~ $(awk_re_bib_item){ if ( \$$2 ~ /$1,/ ) { foo(); }} \
	toupper(\$$0) !~ $(awk_re_bib_item){ if (lb != rb) { foo(); }}" $2
endef

########
## $(call sh_get_bibpreamble, master_bib)
## Retrive preamble from master bib
define sh_get_bibpreamble
$(AWK) "$(awk_fnc_pcntbrc) \
	toupper(\$$0)  ~ $(awk_re_bib_prem){ print \"\"; foo(); } \
	toupper(\$$0) !~ $(awk_re_bib_prem){ if (lb != rb) { foo(); }}" $1
endef

########
## $(call sh_make_partial_bib, cite_keys, master_bib, target_bib)
## Make a partial bib file $3=target_bib by retrieving preamble and
## items identified by keys cited in $1=tex_source from $2=master_bib.
define sh_make_partial_bib
if [ "$2" != "$3" ]; then \
echo > $3; $(call sh_get_bibpreamble, $2) >> $3; echo >> $3; \
$(foreach k,$(sort $1), $(call sh_get_bibitem_by_key,$k,$2) >> $3; echo >> $3;) \
echo >> $3; fi
endef

############# Check TeX file for dependency #############
## $(call define sh_echo_tex_cmd_args,filename,latexcommand,suffix)
## scan file list in $1 for uncommented command \$2[OPTS]{ARGS} for comma
## separated list of file in ARGS
## then, echo ARGS if it already has suffix $3, otherwise ARGS.$3
## $1 is a space separated list of filenames
## $2 is a colon separated list of latex commands
## $3 is a list of suffix to match
## $4 (OPTIONAL) is a default list of suffix to print when all suffix in $3 failed.
re_grep_texcmd="$(re_texcmd)\($(subst :,\|,$2)\)\(\|$(re_texopt)\)$(re_texarg)"
define sh_echo_tex_cmd_args
[ -f $(1) ] && grep -o $(re_grep_texcmd) $(1) \
    | grep -o "$(re_texarg)" | tr -d "{}" | tr , "\n" | while read f; do \
    $(foreach s,$3,( [[ $${f%.$s}.$s = $${f} ]] && echo $${f} && continue );) \
    $(if $4,$(foreach s,$4,echo $${f}.$s;),$(foreach s,$3,echo $${f}.$s;)) \
    done
endef

## $(call tex_children, tex_file)
## prints the arguments of uncommented \input and \include command in tex_file
define tex_children
$(shell $(call sh_echo_tex_cmd_args,$1,include:input,tex))
endef
##

## $(call tex_all_descendants, tex_file)
## All descendants of tex_file
## FIXME: NO WARNING FOR POTENTIAL RECURSION HAZARD
define tex_all_descendants 
$(call tex_children,$1)\
$(foreach inp,$(call tex_children,$1),$(call tex_all_descendants,$(inp)))
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
###### END: Check TeX file for dependency ######

############## BEGIN: Pretty print #############
### print string using color
# $(call cprintf,"STR",COLOR)
define sh_cprintf
printf "$2$1$(ERST)"
endef

### Announce what's being run in color
# $(call sh_cprun,COM,ARG1,ARG2)
# Running COM on ARG1 to make ARG2
define sh_cprun
printf "Running $(ERED)%12s$(ERST) on $(EYLW)%20s$(ERST) to make $(EGRN)%s$(ERST).\n" "$1" "$(strip $2)" "$(strip $3)"
endef
############# END: Pretty print #############

############# BEGIN: LaTeX grind works #############
### analyze tex file for argument to bibtex and run bibtex.
#  if an uncommented \bibliography{AUG} macro is found, print TEXFILEBASENAME.aux
#  else assume using multibib, each \newcites{ARG} gets and aux file with filename ARG.aux
# $(call sh_auxlist foo.tex)
define sh_auxlist
if [ -n "$$($(GREP) -o "^[^%]*\\\\bibliography{[^{}]*}" $1)" ]; \
then echo $(1:.tex=.aux); \
else $(GREP) -o "^[^%]*\\newcites{[^{}]*}" $1 | \
  $(SED) 's:.*\\newcites{\([^{}]*\)}:\1:' | \
  tr ',' ' '; fi
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

# $(call sh_check_warning, logfile)
define sh_check_warning
$(GREP) "Warning:" $(1:%.tex=%.log) | sed -e 's,^\(.*Warning\):,  $(ERED)\1$(ERST):,'
endef

# $(call sh_run_tex, source_file, target_suffix)
pdfLATEX:=$(PDFLATEX)
dviLATEX:=$(LATEX)
define sh_run_tex
$(call sh_cprun,$(value $2LATEX),$1,$(1:%.tex=%.$2)); \
$(value $2LATEX) $(TEXOPTS) $1 $(NULLOUT);            \
$(call sh_check_warning,$1)
endef

define sh_run_dvips
$(call sh_cprun,$(DVIPS),$1,$(1:%.dvi=%.ps)); \
$(DVIPS) $1 $(NULLERR)
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

##################################################
## $(call recipe_partial_bib, tex_file, source_bib)
## make partial bib file by selecting bib items from $2 source_bib with
## keys cited in $1 tex_file
## Assumes : macro $1_cites defined
define recipe_make_partial_bib
$(filter-out $(MAINBIB),$(value $1_bibs)) : $1 $2
	# $$(foreach x,$$< $$(value $$<_texs),$$(value $$x_cites))
	@$$(call sh_make_partial_bib, \
		$$(foreach x,$$< $$(value $$<_texs),$$(value $$x_cites)), \
		$$(filter %.bib,$$^),$$@)
endef

##################################################
## $(call recipe_make_from_tex, tex_file, target_suffix)
## That MASTER rule and recipe for doing all the latex, bibtex, etc.
## 1. With the correct dependency list, run (pdf)latex to generate target
## 2. Scan log for Warning.
## 3. If citation warning is found, rerun bibtex/(pdf)latex until all such
##    warning vanishes
## 4. If citation warning persists after MAXRPT tries, quit and print list
##    of unsatisfied citation/labels.
define recipe_make_from_tex
$(if $(filter pdf,$2), tool:=pdftex,  \
	$(if $(filter dvi,$2), tool:=tex, \
		$(error "What the heck is $2?")))
$(1:%.tex=%.$2) : $(value $1_$2deps)
	### list changed requisite:
	@printf "+ $$(EBLU)%s$$(ERST) \n" "$$?"
	### Run $$(tool) and bibtex once:
	@if ( printf "$$?" | $$(GREP) -q "\.bib\s\+" ); then    \
$$(call sh_run_tex, $$<,$2) && $$(call sh_runbib, $$<); fi; \
$$(call sh_run_tex, $$<,$2)
	### repeat $$(tool)/bibtex up to $$(MAXRPT) times or until no more undefined reference warning 
	@m=0; while $$(GREP) -q $$(GRPW1) $$(PDFLOG)               \
&& [ "$$$$m" -lt $$(MAXRPT) ]; do                           \
$$(call sh_runbib, $$<) && $$(call sh_run_tex, $$<,$2);     \
m=$$$$(( m + 1 )); done;
	### repeat $$(tool)/bibtex up to $$(MAXRPT) times or until no more label changed warning
	@m=0; while $$(GREP) -q $$(GRPW2) $$(PDFLOG)               \
&& [ "$$$$m" -lt $$(MAXRPT) ]; do                           \
$$(call sh_run_tex,$$<,$2) ;                                \
m=$$$$(( m + 1 )); done;
	@echo
endef
#$$(GREP) -o $$(GRPW3) $$(PDFLOG) | grep -o "[^\`]*$$$$";    \

define recipe_make_zip_package
$(1:%.tex=%_pdf.zip) : $(1:%.tex=%.pdf)
	zip $$@ $(1:%.tex=%.pdf) $$(value $1_pdfdeps) $(NULLOUT)
$(1:%.tex=%_ps.zip) : $(1:%.tex=%.ps)
	zip $$@ $(1:%.tex=%.ps) $$(value $1_dvideps) $(NULLOUT)
$(1:%.tex=%.zip) : $(1:%.tex=%.pdf)
	zip $$@ $$(value $1_pdfdeps) $$(value $1_dvideps) $(NULLOUT)
endef

############# Usual rules #############
%.ps : %.dvi
	@$(call sh_run_dvips, $<);

#####################################################################################
# Use documentclass macro to identity master tex source
MASTER_TEX = $(shell grep -l "^\\\\documentclass$(re_texopt)$(re_texarg)" *.tex)
# Target list by simple substitution
TARGET_PDF = $(MASTER_TEX:%.tex=%.pdf)
TARGET_DVI = $(MASTER_TEX:%.tex=%.dvi)
TARGET_PS  = $(MASTER_TEX:%.tex=%.ps)

# Define macros BASE.tex_texs, BASE.tex_bibs, BASE.tex_figs, BASE.tex_deps
$(call  macro_tex_depinfo, $(MASTER_TEX))
$(call  macro_tex_citeinfo, $(MASTER_TEX))

#####################################################################################
all:
# to be overwritten later?

depinfo:
	@printf "========================================\n"
	@printf "%s << $(EYLW)%s$(ERST)\n  \
$(EGRN)incls$(ERST)    : %s\n  \
$(EGRN)bibs$(ERST)     : %s\n  \
$(EBLU)graphics$(ERST) : %s\n  \
$(EBLU)images$(ERST)   : %s\n  \
$(ERED)latex$(ERST)    : %s\n  \
$(ERED)pdflatex$(ERST) : %s\n========================================\
\n" $(foreach x, $(MASTER_TEX), \
"$(x:%.tex=%.pdf)" "$x" "$(value $x_texs)" "$(value $x_bibs)" \
"$(sort $(filter %.eps %.pdf,$(value $x_figs)))"              \
"$(sort $(filter %.jpeg %.jpg %.png,$(value $x_figs)))"       \
"$(value $x_dvideps)" "$(value $x_pdfdeps)") | fmt -s -w 75

citeinfo:
	@printf "$(EYLW)%s$(ERST) : %s\n" $(foreach x, $(MASTER_TEX), "$(x)" "$(value $x_cites)" \
		$(foreach y,$(value $x_texs),"$y" "$(value $y_cites)")) | fmt -s -w 75 -u -t

.PHONY : depinfo citeinfo

#####################################################################################
$(foreach x,$(MASTER_TEX),$(eval $(call recipe_make_from_tex,$x,dvi)))

$(foreach x,$(MASTER_TEX),$(eval $(call recipe_make_from_tex,$x,pdf)))

$(foreach x,$(MASTER_TEX),$(eval $(call recipe_make_zip_package,$x)))
#####################################################################################
## Make partial .bib from master .bib file defined in $(MAINBIB)
ifdef MAINBIB
#BIBPROG = mkBiBfTeX.py
#RUNBIB  = ./$(BIBPROG)
#%.bib : %.tex $(MAINBIB) $(BIBPROG)
#	### Generating partial bibliography from master file $(MAINBIB):
#	@printf "+ $(EBLU)%s$(ERST) \n" "$?"
#	@$(call sh_cprun,mkBiBfTex.py,$?,$@);
#	@$(RUNBIB) $< $(MAINBIB) > _$@ && mv _$@ $@ || rm _$@

$(foreach x,$(MASTER_TEX),$(eval $(call recipe_make_partial_bib,$x,$(MAINBIB))))
endif
############################################################################
