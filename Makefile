.PHONY: all build clean install uninstall

PREFIX?=/usr/local
BINDIR=$(PREFIX)/bin
BUILDDIR=.build
CONFIGURATION?=release

all: build

build:
	swift build -c $(CONFIGURATION)

clean:
	swift package clean
	rm -rf $(BUILDDIR)

install: build
	install -d "$(BINDIR)"
	install "$(BUILDDIR)/$(CONFIGURATION)/combr" "$(BINDIR)/combr"

uninstall:
	rm -f "$(BINDIR)/combr"

run: build
	$(BUILDDIR)/$(CONFIGURATION)/combr