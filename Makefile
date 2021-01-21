bindir = /usr/local/bin

build:
	swift build -c release

install: build
	install ".build/release/swift-outdated" "$(bindir)"

uninstall:
	rm -rf "$(bindir)/swift-outdated"

clean:
	rm -rf .build

.PHONY: build install uninstall clean
