prefix ?= /usr/local
bindir = $(prefix)/bin

build:
	# disabling the sandbox is necessary for installation with homebrew
	swift build -c release --disable-sandbox

install: build
	install ".build/release/swift-outdated" "$(bindir)"

uninstall:
	rm -rf "$(bindir)/swift-outdated"

clean:
	rm -rf .build

.PHONY: uninstall clean
