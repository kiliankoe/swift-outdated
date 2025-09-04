# swift-outdated

A swift subcommand for checking if your dependencies have an update available. This especially applies to updates outside of your version requirements.

Heavily inspired by [cargo-outdated](https://github.com/kbknapp/cargo-outdated).

Calling `swift package update` will only update to the latest available requirements inside your specified version requirements, which totally makes sense, but you might miss that there's a new major version available if you don't check the dependency's repository regularly.

This tool aims to help with that by allowing to quickly check if any requirements might be outdated, it does this by checking the remote git tags of your dependencies to see if something outside of your version requirements is available.

## Installing

### Homebrew

`swift-outdated` can be installed via Homebrew.

```bash
$ brew install swift-outdated
```

### [Mint](https://github.com/yonaskolb/mint)

`swift-outdated` can also be installed via [Mint](https://github.com/yonaskolb/mint).

```bash
$ mint install kiliankoe/swift-outdated
```

## Usage

Since `swift-outdated` installs with its name, it can be called just like a subcommand of Swift itself via `swift outdated`.

```
$ swift outdated
| Package               | Current | Latest | URL                                                |
|-----------------------|---------|--------|----------------------------------------------------|
| rainbow               | 3.2.0   | 4.0.1  | https://github.com/onevcat/rainbow.git             |
| swift-argument-parser | 1.1.4   | 1.2.2  | https://github.com/apple/swift-argument-parser.git |
```

This lists all your outdated dependencies, the currently resolved version and the latest version available in their upstream repository.

### Listing all dependencies

`swift-outdated` also allows listing all your dependencies alongside the ones that are not up to date.

Run the application using `-u` or `--include-up-to-date` command line switch and it will print out current dependencies with their version and ignored ones with their revisions.

### Library

This packages also exposes a library target called `Outdated`. Use this if you want to integrate the functionality into your project.

Here's a basic usage example.

```swift
import Outdated

let pins = try SwiftPackage.currentPackagePins(in: .current)
let packages = await SwiftPackage.collectVersions(for: pins, ignoringPrerelease: true)
packages.output(format: .markdown)
```

### Xcode

`swift-outdated` also supports Xcode projects that use Swift packages for their dependency management. Either run it manually inside your repo
or set up a Run Script Phase. In the latter case `swift-outdated` emits warnings for your outdated dependencies.

<img width="247" alt="Xcode warnings screenshot" src="https://user-images.githubusercontent.com/2625584/104966116-6cedc400-59e0-11eb-9dc0-942f860e9e33.png">

Be aware however that using a Run Script Phase in this way will fetch available versions for all of your dependencies on every build, which will
increase your build time by a second or two. You're probably better off running this manually every now and then.
