#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

mkdir -p build
xcrun swiftc \
    -swift-version 5 \
    Sources/Models.swift \
    Sources/ProfileStore.swift \
    Sources/NetworkInterfaceStore.swift \
    Tests/ModelTests.swift \
    -o build/model-tests
build/model-tests
