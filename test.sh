#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p build
xcrun swiftc -swift-version 6 Sources/Battery.swift Tests/main.swift -o build/checks
build/checks "$PWD/build/preview.png"
