#!/bin/sh
set -e

cd "$(dirname "$0")"

swift build -c release --build-path ./dist
