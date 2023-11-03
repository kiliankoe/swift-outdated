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

bump-homebrew:
	VERSION=$$(grep -Eo 'version: \"[0-9.]+\"' ./Sources/SwiftOutdated/SwiftOutdated.swift | sed 's/version: //' | tr -d \"); \
	brew bump-formula-pr --strict swift-outdated --tag=$$VERSION --version=$$VERSION

.PHONY: uninstall clean bump-homebrew
