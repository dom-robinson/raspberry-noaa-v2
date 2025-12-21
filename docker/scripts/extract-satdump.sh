#!/bin/bash
# Extract SatDump files from host system for Docker image
# This creates a portable SatDump installation that works on any machine

set -e

EXTRACT_DIR="${1:-docker/satdump-files}"
mkdir -p "$EXTRACT_DIR"

echo "Extracting SatDump files to $EXTRACT_DIR..."

# Create directory structure
mkdir -p "$EXTRACT_DIR/usr/bin"
mkdir -p "$EXTRACT_DIR/usr/lib"
mkdir -p "$EXTRACT_DIR/usr/lib/arm-linux-gnueabihf"
mkdir -p "$EXTRACT_DIR/usr/share/satdump"

# Copy main binary
if [ -f /usr/bin/satdump ]; then
    cp /usr/bin/satdump "$EXTRACT_DIR/usr/bin/"
    echo "✓ Copied /usr/bin/satdump"
else
    echo "ERROR: /usr/bin/satdump not found!"
    exit 1
fi

# Copy core library
if [ -f /usr/lib/libsatdump_core.so ]; then
    cp /usr/lib/libsatdump_core.so "$EXTRACT_DIR/usr/lib/"
    echo "✓ Copied /usr/lib/libsatdump_core.so"
fi

# Copy shared libraries
for lib in libjemalloc.so.2 libvolk.so.2.4 libnng.so.1.4.0; do
    if [ -f "/usr/lib/arm-linux-gnueabihf/$lib" ]; then
        cp "/usr/lib/arm-linux-gnueabihf/$lib" "$EXTRACT_DIR/usr/lib/arm-linux-gnueabihf/"
        echo "✓ Copied /usr/lib/arm-linux-gnueabihf/$lib"
    fi
done

# Create symlink for libnng
if [ -f "$EXTRACT_DIR/usr/lib/arm-linux-gnueabihf/libnng.so.1.4.0" ]; then
    ln -sf libnng.so.1.4.0 "$EXTRACT_DIR/usr/lib/arm-linux-gnueabihf/libnng.so.1"
    echo "✓ Created symlink libnng.so.1"
fi

# Copy SatDump config and plugins
if [ -d /usr/share/satdump ]; then
    cp -r /usr/share/satdump/* "$EXTRACT_DIR/usr/share/satdump/" 2>/dev/null || true
    echo "✓ Copied /usr/share/satdump"
fi

# Copy any plugins from /usr/lib/satdump if they exist
if [ -d /usr/lib/satdump ]; then
    mkdir -p "$EXTRACT_DIR/usr/lib/satdump"
    cp -r /usr/lib/satdump/* "$EXTRACT_DIR/usr/lib/satdump/" 2>/dev/null || true
    echo "✓ Copied /usr/lib/satdump plugins"
fi

echo ""
echo "SatDump files extracted to $EXTRACT_DIR"
echo "Total size: $(du -sh "$EXTRACT_DIR" | awk '{print $1}')"
echo ""
echo "Next steps:"
echo "1. Commit these files to git (they're needed for Docker build)"
echo "2. Update Dockerfile to COPY these files instead of using .deb"

