define lsnoerr
$(shell ls $1 2> /dev/null)
endef

## Scan gnuplot source ($1) for tex file output
define gnuplot_outs
$(shell \
  egrep "^[[:space:]]*set (o|output) '[^']*tex'" $1 \
  | while read f; do IFS="'"; set -- $$f; printf "$$2\n"; done; \
  egrep "^[[:space:]]*set (o|output) \\\"[^\\\"]*tex\\\"" $1 \
  | while read f; do IFS=\\\"; set -- $$f; printf "$$2\n"; done; )
endef

## Scan gnuplot source ($1) for data file dependency (manual)
define gnuplot_deps
$(strip $(shell egrep "^#[ ]*datadep:" $1 \
  | while read f; do IFS=:; set -- $$f; printf "$$2\n"; done ))
endef

## Scan python source ($1) for argument to savefig
define python_outs
$(foreach py, $(1), \
	$(shell grep "^\([^#]*\W\|\)savefig([^()]*)" $(py) \
	| grep -o "[^'\"]*pdf" ))
endef

## Scan mathematica notebook ($1) for argument to Export
define mathnb_export
$(foreach mathnb, $(1), \
	$(shell [ -f "$(mathnb)" ] && cat $(1) | tr -d "\r\n" | grep -o "Export[^>]*" | grep -o "[^<>\\]*$(strip $2)"))
endef

# C related
CC     = gcc
CFLAGS = -Wall -O2
LFLAGS =
LDLIBS = m gsl

# pretty printing
# ANSI color codes
RS   = [0m
FRED = [1;31m
FGRN = [1;32m
FYEL = [1;33m
define cprun 
printf "Running $(FRED)%8s$(RS) to make $(FYEL)%35s$(RS) from $(FGRN)%s$(RS)\n" "$1" "$3" "$2";
endef
