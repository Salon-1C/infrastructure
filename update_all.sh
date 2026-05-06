#!/bin/zsh
# This script will update all repos in of the parent directory
echo "Updating all repos.."
echo "\nThis will update all repos in their current branches, make sure to commit or stash any changes before running this script"

cd ..
TARGET_PATH=$(pwd)
echo -e "All repos in [$TARGET_PATH] will be updated.."
echo "Is this folder correct? (y/n)"
read -r RESPONSE
if [[ "$RESPONSE" != "y" ]]; then
  echo "Aborting.."
  exit 1
  fi
# Loops through all directories in the parent path
for d in "$TARGET_PATH"/*/; do
  # Checks if the directory is a git repository
  if [ -d "$d/.git" ]; then
      (
        cd "$d" || exit
        REPO_NAME=$(basename "$d")

        BRANCH=$(git branch --show-current)
        echo "----------------------------------------------"
        echo "\nUpdating [$REPO_NAME] on branch [$BRANCH].."

        git pull
      )
    fi
    done

