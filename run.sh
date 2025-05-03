#!/bin/bash
# Simple script to build and run combr

set -e

echo "Building combr..."
swift build

echo "Running combr..."
.build/debug/combr "$@"