#!/bin/bash
# Helper script to install satdump from host into RN2 container
# Run this on the wrx host if satdump .deb installation fails

set -e

CONTAINER_NAME="${1:-rn2}"

echo "Installing satdump from host into container: $CONTAINER_NAME"

# Check if satdump exists on host
if [ ! -f /usr/bin/satdump ]; then
    echo "ERROR: satdump not found on host at /usr/bin/satdump"
    exit 1
fi

# Create directories in container
docker exec $CONTAINER_NAME mkdir -p /usr/lib/arm-linux-gnueabihf

# Copy binary
echo "Copying satdump binary..."
docker cp /usr/bin/satdump $CONTAINER_NAME:/usr/bin/satdump
docker exec $CONTAINER_NAME chmod +x /usr/bin/satdump

# Copy libraries
echo "Copying libraries..."
docker cp /usr/lib/libsatdump_core.so $CONTAINER_NAME:/usr/lib/ 2>/dev/null || true
docker cp /usr/lib/arm-linux-gnueabihf/libjemalloc.so.2 $CONTAINER_NAME:/usr/lib/arm-linux-gnueabihf/ 2>/dev/null || true
docker cp /usr/lib/arm-linux-gnueabihf/libvolk.so.2.4 $CONTAINER_NAME:/usr/lib/arm-linux-gnueabihf/ 2>/dev/null || true
docker cp /usr/lib/arm-linux-gnueabihf/libnng.so.1.4.0 $CONTAINER_NAME:/usr/lib/arm-linux-gnueabihf/ 2>/dev/null || true

# Create symlink for libnng
docker exec $CONTAINER_NAME ln -sf libnng.so.1.4.0 /usr/lib/arm-linux-gnueabihf/libnng.so.1 2>/dev/null || true

# Copy satdump config directory
echo "Copying satdump config..."
docker exec $CONTAINER_NAME mkdir -p /usr/share/satdump
docker cp /usr/share/satdump/satdump_cfg.json $CONTAINER_NAME:/usr/share/satdump/ 2>/dev/null || true
docker cp /usr/share/satdump/pipelines $CONTAINER_NAME:/usr/share/satdump/ 2>/dev/null || true
docker cp /usr/share/satdump/resources $CONTAINER_NAME:/usr/share/satdump/ 2>/dev/null || true

# Install missing dependencies
echo "Installing missing dependencies..."
docker exec $CONTAINER_NAME apt-get update -qq
docker exec $CONTAINER_NAME apt-get install -y libfftw3-3 libfftw3-single3 liborc-0.4-0 2>&1 | grep -E "(Setting up|Unpacking)" || true

# Verify installation
echo ""
echo "Verifying satdump installation..."
if docker exec $CONTAINER_NAME satdump --version >/dev/null 2>&1; then
    echo "✓ satdump installed successfully!"
    docker exec $CONTAINER_NAME satdump --version 2>&1 | head -3
else
    echo "✗ satdump installation failed. Check dependencies."
    docker exec $CONTAINER_NAME ldd /usr/bin/satdump 2>&1 | grep "not found" || echo "All dependencies satisfied"
fi

