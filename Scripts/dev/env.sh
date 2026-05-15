# Source this before running swift commands in this project.
# usage: source Scripts/dev/env.sh && swift build && swift test
#
# Why: this machine has only Command Line Tools, not full Xcode. The
# standalone Swift toolchain at ~/Library/Developer/Toolchains/swift-latest
# provides swift-testing (Apple's modern test framework, which replaces
# XCTest in our spec §9.1). We prepend its bin to PATH so plain `swift`
# resolves to the right binary.
#
# We also unset CC/CXX because this user's shell exports CC=gcc-11 globally,
# which breaks SwiftPM's C-shim compilation for swift-nio and friends.

export PATH="$HOME/Library/Developer/Toolchains/swift-latest.xctoolchain/usr/bin:$PATH"
unset CC CXX
