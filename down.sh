#!/bin/bash

# Usage: ./download-github-zip.sh --top 3

DOWNLOAD_DIR="./github-zips"  # 设置下载目录

while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --top)
      TOP="$2"
      shift
      shift
      ;;
    *)
      shift
      ;;
  esac
done

if [ -z "$TOP" ]; then
  TOP=3
fi

mkdir -p "$DOWNLOAD_DIR"  # 创建下载目录

echo "Fetching data from npmrank.net..."
DATA=$(curl -s "https://www.npmrank.net/api/ranking/packages/last-year?top=$TOP")

# Check if curl was successful
if [ $? -ne 0 ]; then
  echo "Failed to fetch data."
  exit 1
fi

echo "Fetching GitHub repositories and downloading zip files..."

for i in $(seq 0 $(($TOP-1))); do
  GITHUB_URL=$(echo $DATA | jq -r ".data[$i].githubUrl")
  PACKAGE_NAME=$(echo $DATA | jq -r ".data[$i].id")

  if [ -z "$GITHUB_URL" ]; then
    echo "No GitHub URL found for package $PACKAGE_NAME"
    continue
  fi

  REPO_NAME=$(echo "$GITHUB_URL" | awk -F/ '{print $4"/"$5}')
  MAIN_BRANCHES=("main" "master")

  # Check if the package zip has already been downloaded
  DOWNLOADED=false
  for BRANCH in "${MAIN_BRANCHES[@]}"; do
    ZIP_FILE="$DOWNLOAD_DIR/$PACKAGE_NAME-$BRANCH.zip"
    if [ -e "$ZIP_FILE" ]; then
      DOWNLOADED=true
      echo "$ZIP_FILE already downloaded. Skipping $PACKAGE_NAME ($BRANCH)."
      break
    fi
  done

  if [ "$DOWNLOADED" = false ]; then
    for BRANCH in "${MAIN_BRANCHES[@]}"; do
      ZIP_URL="https://github.com/$REPO_NAME/archive/refs/heads/$BRANCH.zip"
      OUTPUT_FILE="$DOWNLOAD_DIR/$PACKAGE_NAME-$BRANCH.zip"

      echo "Downloading $PACKAGE_NAME from $ZIP_URL (branch: $BRANCH)..."
      curl -s -L -o "$OUTPUT_FILE" "$ZIP_URL"

      if [ $? -eq 0 ]; then
        echo "Downloaded $OUTPUT_FILE successfully."
        break  # Successfully downloaded, no need to try other branches
      else
        echo "Failed to download $OUTPUT_FILE from $ZIP_URL."
      fi
    done
  fi
done

echo "All downloads completed."
