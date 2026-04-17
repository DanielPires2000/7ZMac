#!/bin/bash
# download_7zz.sh
# Automates downloading the latest 7-Zip macOS console version (7zz).
# Meant to be run as an Xcode Build Phase before compiling.

set -e

# Skip the web request for 7zz if we are just compiling for SwiftUI Previews
if [ "${ENABLE_PREVIEWS}" == "YES" ]; then
    echo "Skipping 7zz download for SwiftUI Previews to save time."
    exit 0
fi

# Configuration
URL_BASE="https://7-zip.org"
TARGET_DIR="${SRCROOT}/7ZMac/Resources"
TEMP_DIR=$(mktemp -d)

# Clean up temp directory on exit
trap 'rm -rf "$TEMP_DIR"' EXIT

echo "Checking for latest 7-Zip version..."

# Fetch the main download page HTML
HTML=$(curl -s "$URL_BASE/download.html")

# Find the download link for the macOS CLI version.
# Look for a link like "a/7z2600-mac.tar.xz"
DOWNLOAD_LINK=$(echo "$HTML" | grep -Eo 'a/7z[0-9]+-mac\.tar\.xz' | head -1)

if [ -z "$DOWNLOAD_LINK" ]; then
    echo "Error: Could not find the macOS download link on 7-zip.org"
    exit 1
fi

FILE_NAME=$(basename "$DOWNLOAD_LINK")
# Extract just the numeric version part from the filename (e.g., 2600 from 7z2600-mac.tar.xz)
VERSION_STR=$(echo "$FILE_NAME" | grep -o '7z[0-9]*' | sed 's/7z//')
DOWNLOAD_URL="$URL_BASE/$DOWNLOAD_LINK"

echo "Latest version found on site: $VERSION_STR"
echo "Download URL: $DOWNLOAD_URL"

# Check currently installed version
CURRENT_VERSION=""
if [ -f "$TARGET_DIR/7zz" ]; then
    # Ensure it's executable first so we can check version
    chmod +x "$TARGET_DIR/7zz" || true
    # Run 7zz to get its version. Output looks like "7-Zip (z) 24.09 (arm64)..."
    CURRENT_VERSION_RAW=$("$TARGET_DIR/7zz" | head -n 2 | grep -i "7-Zip")
    # Extract only the digits, e.g. "24.09" -> "2409"
    CURRENT_VERSION=$(echo "$CURRENT_VERSION_RAW" | grep -Eo '[0-9]+\.[0-9]+' | sed 's/\.//g' | head -1)
    echo "Current installed version: $CURRENT_VERSION"
else
    echo "7zz not found at $TARGET_DIR. Will download."
fi

# Compare versions
if [ "$VERSION_STR" == "$CURRENT_VERSION" ]; then
    echo "7zz is already up to date (version $VERSION_STR). Skipping download."
    exit 0
fi

echo "Downloading $FILE_NAME..."
curl -L -s -o "$TEMP_DIR/$FILE_NAME" "$DOWNLOAD_URL"

echo "Extracting..."
mkdir -p "$TARGET_DIR"

# Extract the archive. 7z macOS release includes local instructions and the binary.
# We only want the binary '7zz'.
tar -xf "$TEMP_DIR/$FILE_NAME" -C "$TEMP_DIR"

# Ensure the binary exists after extraction
if [ ! -f "$TEMP_DIR/7zz" ] && [ ! -f "$TEMP_DIR/7zzMac" ]; then
    echo "Error: Extracted archive did not contain 7zz binary!"
    exit 1
fi

# Remove the old binary first to avoid "Permission denied" when overwriting
rm -f "$TARGET_DIR/7zz"

# Copy the binary to the target directory
if [ -f "$TEMP_DIR/7zz" ]; then
    cp "$TEMP_DIR/7zz" "$TARGET_DIR/7zz"
elif [ -f "$TEMP_DIR/7zzMac" ]; then
    # Older versions sometimes named it 7zzMac
    cp "$TEMP_DIR/7zzMac" "$TARGET_DIR/7zz"
fi

# Ensure it is executable
chmod +x "$TARGET_DIR/7zz"

echo "Successfully updated 7zz to version $VERSION_STR in $TARGET_DIR"
exit 0
