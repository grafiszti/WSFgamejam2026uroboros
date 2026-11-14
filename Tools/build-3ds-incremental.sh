#!/bin/bash
#
# Incremental 3DS build used by `make 3dsx` / `make cia`.
#
# The stock `build-3ds` helper wipes /intermediate on every run, so the game
# objects are lost and Polyphase headless mode recompiles the engine and every
# project source from scratch. This script instead mirrors the mounted project
# into a persistent /intermediate directory and lets make reuse the cached
# objects. The engine/Bullet caches under /polyphase are persisted by named
# Docker volumes in the Makefile.
#
set -euo pipefail

SOURCE_DIR=/project
BUILD_DIR=/intermediate

OCTP_FILE=$(find "$SOURCE_DIR" -maxdepth 1 -name '*.octp' -print -quit)
if [ -z "$OCTP_FILE" ]; then
    echo "Error: no .octp project file found in $SOURCE_DIR" >&2
    exit 1
fi
OCTP_NAME=$(basename "$OCTP_FILE")

mkdir -p "$BUILD_DIR"

# Drop the 3DS object caches when the underlying Polyphase image changes.
# Otherwise a newer image's older source mtimes could leave stale objects that
# make considers up to date.
STAMP_FILE="$BUILD_DIR/.polyphase-image-id"
if [ -n "${POLYPHASE_IMAGE_ID:-}" ]; then
    if [ -f "$STAMP_FILE" ] && [ "$(cat "$STAMP_FILE")" != "$POLYPHASE_IMAGE_ID" ]; then
        echo "Polyphase image changed; clearing 3DS build caches..."
        rm -rf \
            /polyphase/Engine/Intermediate/3DS \
            /polyphase/Engine/Build/3DS \
            /polyphase/External/Bullet/Intermediate/3DS \
            /polyphase/External/Bullet/Build/3DS \
            /polyphase/Standalone/Intermediate/3DS \
            /polyphase/Standalone/Build/3DS
    fi
    printf '%s' "$POLYPHASE_IMAGE_ID" > "$STAMP_FILE"
fi

# Remove everything that is not a build cache, then refresh the sources from
# /project. tar preserves mtimes, so unchanged files do not trigger recompiles.
for entry in "$BUILD_DIR"/* "$BUILD_DIR"/.[!.]* "$BUILD_DIR"/..?*; do
    [ -e "$entry" ] || continue
    case "$(basename "$entry")" in
        Intermediate|Build|Generated|Packaged|Makefile_TEMP|.polyphase-image-id) continue ;;
    esac
    rm -rf -- "$entry"
done

tar -C "$SOURCE_DIR" \
    --exclude=./Packaged \
    --exclude=./Intermediate \
    --exclude=./Generated \
    --exclude=./Build \
    --exclude=./Makefile_TEMP \
    --exclude=./Makefile_3DS \
    --exclude=./.git \
    --exclude=./.github \
    --exclude=./.idea \
    --exclude=./.opencode \
    --exclude=./Saves \
    --exclude=./dist \
    --exclude=./output \
    --exclude=./.tmp \
    -cf - . | tar -C "$BUILD_DIR" -xf -

echo "Building for Nintendo 3DS (incremental)..."
echo "Project: $SOURCE_DIR"
echo "Build dir: $BUILD_DIR"
echo "Project file: $BUILD_DIR/$OCTP_NAME"

cd /polyphase
./PolyphaseEditor.elf -headless -project "$BUILD_DIR/$OCTP_NAME" -build 3DS embedded

cp -f "$BUILD_DIR"/Packaged/3DS/*.3dsx /game/
chmod 666 /game/*.3dsx
echo "Done! 3DS build at /game/"
