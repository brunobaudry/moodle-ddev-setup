#!/bin/bash

# -------------------------------
# ✅ Environment Checks
# -------------------------------
check_environment() {
  if ! command -v docker > /dev/null; then
    echo "❌ Docker is not running or not installed."
    exit 1
  fi

  if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker daemon is not running. Please start Docker."
    exit 1
  fi

  if ! command -v ddev > /dev/null; then
    echo "❌ DDEV is not installed. Please install DDEV."
    exit 1
  fi

  if ! command -v composer > /dev/null; then
    echo "❌ Composer is not installed. Please install Composer."
    exit 1
  fi

  if ! command -v jq > /dev/null; then
    echo "❌ jq is not installed. Please install jq (used to parse DDEV output)."
    exit 1
  fi
  echo "✅ All tools are available"
}
