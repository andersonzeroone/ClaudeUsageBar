#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
swiftc -O -parse-as-library -o claude-usagebar App.swift
echo "Built ./claude-usagebar"
