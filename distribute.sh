#!/bin/bash

for dir in Question-*; do
  if [ -d "$dir" ]; then
    new_name=$(echo "$dir" | tr ' ' '-')
    
    if [ "$dir" != "$new_name" ]; then
      echo "Renaming: $dir -> $new_name"
      mv "$dir" "$new_name"
    fi
  fi
done

echo "Done!"
