# -*- makefile-gmake -*-

all:
.PHONY: all dist

dist:
	tar cavf a.tar.xz arxiv2???????.htm 201312

# all:
# 	./chkarxiv.sh

r%.htm: src/r%.lst
	./chkarxiv.sh list $< $@
jc%.htm: src/jc%.lst
	./chkarxiv.sh list $< $@
s%.htm: src/s%.lst
	./chkarxiv.sh list $< $@

all: r201412.htm jc201503.htm jc201510.htm jc201512.htm
all: r201501.htm r201502.htm r201503.htm r201504.htm r201505.htm r201506.htm
all: r201507.htm r201508.htm r201509.htm r201510.htm r201511.htm r201512.htm
all: r201601.htm
all: s201512.htm
