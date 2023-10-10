#!/bin/bash

# Usage: ./download-github-zip.sh --top 3

DOWNLOAD_DIR="./github-zips"  # 设置下载目录
MAX_AGE_DAYS=30  # 设置最大文件年龄（以天为单位）
FAILURE_LOG="./$DOWNLOAD_DIR/failure.log"  

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

if [ ! -f "$FAILURE_LOG" ]; then  
    touch "$FAILURE_LOG"  
fi

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
  MAIN_BRANCHES=("master" "main")

  # Check if the package zip has already been downloaded and is less than MAX_AGE_DAYS old
  DOWNLOADED=false
  for BRANCH in "${MAIN_BRANCHES[@]}"; do
    ZIP_FILE="$DOWNLOAD_DIR/$PACKAGE_NAME-$BRANCH.zip"
    if [ -e "$ZIP_FILE" ]; then
      FILE_AGE_DAYS=$(($(($(date +%s) - $(date -r "$ZIP_FILE" +%s))) / 86400))
      if [ "$FILE_AGE_DAYS" -le "$MAX_AGE_DAYS" ]; then
        DOWNLOADED=true
        echo "$ZIP_FILE already downloaded and is less than $MAX_AGE_DAYS days old. Skipping $PACKAGE_NAME ($BRANCH)."
        break
      fi
    fi
  done

  if [ "$DOWNLOADED" = false ]; then
    for BRANCH in "${MAIN_BRANCHES[@]}"; do
      # ZIP_URL="http://github.com/$REPO_NAME/archive/refs/heads/$BRANCH.zip"
      ZIP_URL="https://gitee.com/mirrors_$REPO_NAME/repository/archive/$BRANCH.zip"

      OUTPUT_FILE="$DOWNLOAD_DIR/$PACKAGE_NAME-$BRANCH.zip"

      echo "Downloading $ZIP_URL"
      curl -s -L -o "$OUTPUT_FILE" "$ZIP_URL"
      if [ $? -eq 0 ] && [ -f "$OUTPUT_FILE" ]; then
        # 读取文件内容  
        file_content=$(cat "$OUTPUT_FILE")  
        # 检查文件内容是否包含 "404"  
        if echo "$file_content" | grep -q "404"; then  
          echo "Failed to download (404)"
          # 删除文件  
          rm -f "$OUTPUT_FILE"  
          continue
        else
          echo "Downloaded successfully!"
          break  # Successfully downloaded, no need to try other branches
        fi
      else
        rm -f "$OUTPUT_FILE"
        echo "$ZIP_URL" >> "$FAILURE_LOG" >> "$FAILURE_LOG"
        echo "Failed to download from $ZIP_URL."
      fi
    done
  fi
done

echo "All downloads completed."
