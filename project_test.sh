#!/usr/bin/env bash
set -e

echo "=============================="
echo "🧪 Running Tests"
echo "=============================="

uv sync --group dev

uv run python -m pytest tests/unit -q

echo "✅ Tests Passed"
