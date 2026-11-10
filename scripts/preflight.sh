#!/usr/bin/env bash
#
# Preflight checks for selenium-e2e-automation-framework.
# Updated to support Windows (Git Bash/MSYS/CYGWIN), macOS, and Linux.
#
set -u

SKIP="${PREFLIGHT_SKIP:-false}"
if [ "$SKIP" = "true" ]; then
  echo "preflight: skipped (PREFLIGHT_SKIP=true)"
  exit 0
fi

fail=0

# Detect Operating System
OS_TYPE="unknown"
case "$(uname -s)" in
    Linux*)   OS_TYPE="linux";;
    Darwin*)  OS_TYPE="mac";;
    CYGWIN*|MSYS*|MINGW*) OS_TYPE="windows";;
esac

have() { command -v "$1" >/dev/null 2>&1; }

echo "preflight: OS detected as $OS_TYPE"

echo "preflight: checking Java..."
if have java; then
  ver="$(java -version 2>&1 | head -1)"
  echo "  found: $ver"
  major="$(echo "$ver" | sed -E 's/.*version "([0-9]+).*/\1/')"
  if [ "${major:-0}" -lt 17 ]; then
    echo "  ERROR: Java 17+ is required."
    fail=1
  fi
else
  echo "  Java not found."
  if [ "$OS_TYPE" = "mac" ] && have brew; then
    echo "  installing via Homebrew..."
    brew install --cask temurin@17 || fail=1
  else
    echo "  Fix: install a Temurin 17 JDK from https://adoptium.net"
    fail=1
  fi
fi

echo "preflight: checking Maven..."
if have mvn; then
  echo "  found: $(mvn -version 2>&1 | head -1)"
else
  echo "  Maven not found."
  if [ "$OS_TYPE" = "mac" ] && have brew; then
    echo "  installing via Homebrew..."
    brew install maven || fail=1
  elif [ "$OS_TYPE" = "linux" ] && have apt-get; then
    echo "  installing via apt..."
    sudo apt-get update -qq && sudo apt-get install -y -qq maven || fail=1
  else
    echo "  Fix: install Maven from https://apache.org and add it to PATH"
    fail=1
  fi
fi

echo "preflight: checking Chrome/Chromium..."
chrome_found=0

if [ "$OS_TYPE" = "windows" ]; then
  # Checks standard 64-bit, 32-bit, local app data (no-admin), and PATH environments
  if [ -f "C:/Program Files/Google/Chrome/Application/chrome.exe" ] || \
     [ -f "C:/Program Files (x86)/Google/Chrome/Application/chrome.exe" ] || \
     [ -f "${LOCALAPPDATA:-}/Google/Chrome/Application/chrome.exe" ] || \
     have chrome.exe || have google-chrome; then
    chrome_found=1
  fi
elif [ "$OS_TYPE" = "mac" ]; then
  if [ -d "/Applications/Google Chrome.app" ] || [ -d "$HOME/Applications/Google Chrome.app" ] || have google-chrome; then
    chrome_found=1
  fi
else
  # Linux options
  if have google-chrome || have chromium || have chromium-browser; then
    chrome_found=1
  fi
fi

if [ "$chrome_found" -eq 1 ]; then
  echo "  found a Chrome/Chromium binary"
else
  echo "  WARNING: no Chrome/Chromium found."
  echo "  Selenium Manager downloads the *driver*, not the browser itself."
  echo "  Fix (Windows): Install Google Chrome from the official site and verify it's in C:\Program Files"
  echo "  Fix (macOS): brew install --cask google-chrome"
  echo "  Fix (Linux): sudo apt-get install -y chromium-browser"
  fail=1
fi

if [ "$fail" -ne 0 ]; then
  echo "preflight: FAILED — fix the items above, then re-run."
  echo "  (Skip this check with: mvn test -Dpreflight.skip=true)"
  exit 1
fi

echo "preflight: OK"
