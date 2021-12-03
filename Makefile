NAME=trash
PREFIX=/usr/local

all: trash.1

trash.1: trash.1.md
	pandoc --lua-filter=.pandoc/bold-code.lua -s $< -t man -o $@

clean:
	rm -f *.1

install: trash.1 trash.pl
	mkdir -p -m 755 "$(PREFIX)/man/man1" "$(PREFIX)/bin"
	cp trash.1 "$(PREFIX)/man/man1/$(NAME).1"
	rm -f "$(PREFIX)/bin/$(NAME)"
	cp trash.pl "$(PREFIX)/bin/$(NAME)"

uninstall:
	rm -rf "$(PREFIX)/bin/$(NAME)" "$(PREFIX)/man/man1/$(NAME).1"

.PHONY: all clean install uninstall
