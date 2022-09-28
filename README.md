# swift-outdated

A swift subcommand for checking if your dependencies have an update available. This especially applies to updates outside of your version requirements.

Heavily inspired by [cargo-outdated](https://github.com/kbknapp/cargo-outdated).

Calling `swift package update` will only update to the latest available requirements inside your specified version requirements, which totally makes sense, but you might miss that there's a new major version available if you don't check the dependency's repository regularly.

This tool aims to help with that by allowing to quickly check if any requirements might be outdated, it does this by checking the remote git tags of your dependencies to see if something outside of your version requirements is available.

## Installing

### [Mint](https://github.com/yonaskolb/mint)

swift-outdated can be installed via [Mint](https://github.com/yonaskolb/mint).

```bash
$ mint install kiliankoe/swift-outdated
```

### Homebrew

`swift-outdated` can be installed via Homebrew, although for the time being via a custom tap.

```bash
$ brew tap kiliankoe/formulae
$ brew install swift-outdated
```

## Usage

Since `swift-outdated` installs with its name, it can be called just like a subcommand of Swift itself via `swift outdated`.

```
$ swift outdated

| Package               | Current | Latest |                                                                                                                                                                   │
|-----------------------|---------|--------|                                                                                                                                                                   │
| Files                 | 4.1.1   | 4.2.0  |                                                                                                                                                                   │
| Rainbow               | 3.1.5   | 4.0.1  |                                                                                                                                                                   │
| Version               | 2.0.0   | 2.0.1  |                                                                                                                                                                   │
| swift-argument-parser | 1.0.2   | 1.1.4  |                                                                                                                                                                   │
```

This lists all your outdated dependencies, the currently resolved version and the latest version available in their upstream repository.

### Xcode

swift-outdated also supports Xcode projects that use Swift packages for their dependency management. Either run it manually inside your repo
or set up a Run Script Phase. In the latter case swift-outdated emits warnings for your outdated dependencies.

<img width="247" alt="Xcode warnings screenshot" src="https://user-images.githubusercontent.com/2625584/104966116-6cedc400-59e0-11eb-9dc0-942f860e9e33.png">

Be aware however that using a Run Script Phase in this way will fetch available versions for all of your dependencies on every build, which will
increase your build time by a second or two. You're probably better off running this manually every now and then.
