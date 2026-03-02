#!/bin/bash

set -e

SOURCE="Question-11-Gateway-API"

# Ensure source exists
if [ ! -d "$SOURCE" ]; then
  echo "Source directory $SOURCE not found!"
  exit 1
fi

# Loop through all Question-* directories
for dir in Question-*; do
  # Skip the source directory itself
  if [ "$dir" != "$SOURCE" ] && [ -d "$dir" ]; then
    echo "Copying to $dir"
    cp -r "$SOURCE" "$dir/"
  fi
done

echo "Done!"
