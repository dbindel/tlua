LDOC=lua /Users/dbindel/work/ldoc/ldoc.lua
DOCS=doc/tlua.html
.PHONY: default html test clean

default: test

html: $(DOCS)

doc/tlua.md: tlua.lua 

doc/%.md: %.lua
	$(LDOC) -p pandoc -attribs '.lua' -o $@ $^

%.html: %.md
	pandoc $< -s --toc -c pandoc.css \
		--highlight-style pygments -o $@

test:
	for fname in test/*.lua ; do lua $$fname ; done

clean:
	rm -f doc/*.html doc/*.pdf doc/*.md
	rm -f *~
	rm -f test/*~
