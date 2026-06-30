MPL ?= mpl
MPLFLAGS ?= -default-type int64 -default-type word64

# Default number of processors for `make run`.
PROCS ?= 4
INPUT ?= inputs/tiny.adj
ALGO ?= seq

.PHONY: all
all: kcore

kcore: kcore.mlb $(wildcard src/*.sml) lib
	$(MPL) $(MPLFLAGS) -output kcore kcore.mlb

# Ensure dependencies are fetched.
lib:
	smlpkg sync

.PHONY: run
run: kcore
	./kcore @mpl procs $(PROCS) -- -input $(INPUT) -algo $(ALGO) --check

.PHONY: clean
clean:
	rm -f kcore
	rm -rf bin

.PHONY: distclean
distclean: clean
	rm -rf lib
