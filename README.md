# swift-outdated

A swift subcommand for checking if your dependencies have an update available. This especially applies to updates outside of your version requirements.

Heavily inspired by [cargo-outdated](https://github.com/kbknapp/cargo-outdated).

**Please be aware that this is just quickly hacked together to try it out, it is by no means complete nor is the implementation ideal.**

Calling `swift package update` will only update to the latest available requirements inside your specified version requirements, which totally makes sense, but you might miss that there's a new major version available if you don't check the dependency's repository regularly.

This tool aims to help with that by allowing to quickly check if any requirements might be outdated, it does this by checking the remote git tags of your dependencies to see if something outside of your version requirements is available.

## Usage

Since `swift-outdated` installs with its name, it can be called just like a subcommand of Swift itself via `swift outdated`.

```
$ swift outdated

----------------------- --------------- --------- --------
 Name                    Requirement     Current   Latest
----------------------- --------------- --------- --------
 swift-argument-parser   0.0.0..<0.1.0   0.0.2     0.0.2
 version                 2.0.0..<3.0.0   2.0.0     2.0.0
 shellout                2.3.0..<3.0.0   2.3.0     2.3.0
 files                   4.0.0..<4.1.0   4.0.2 ⬆️  4.1.1
 swiftytexttable         0.9.0..<1.0.0   0.9.0     0.9.0
 rainbow                 3.0.0..<4.0.0   3.1.5     3.1.5
----------------------- --------------- --------- --------
```

In this example output the dependency `files` is pinned to a version requirement of `.upToNextMinor(from: "4.0.0")`, which does not include the most recent available version `4.1.1`.

