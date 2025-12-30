#!/bin/bash
# Disk space analysis script for Pi400

echo "=== Disk Usage Overview ==="
df -h

echo ""
echo "=== Top-level directory sizes (excluding system dirs) ==="
du -sh /home /opt /usr/local /var/lib /tmp /root 2>/dev/null | sort -h

echo ""
echo "=== Docker disk usage ==="
if command -v docker &> /dev/null; then
    echo "Docker system disk usage:"
    docker system df 2>/dev/null || echo "Docker not running or no permission"
    
    echo ""
    echo "Docker data directory:"
    du -sh /var/lib/docker 2>/dev/null || echo "Cannot access /var/lib/docker"
fi

echo ""
echo "=== Largest files in /home (top 20) ==="
find /home -type f -size +100M -exec du -h {} + 2>/dev/null | sort -h | tail -20

echo ""
echo "=== Largest files in /var (top 20) ==="
find /var -type f -size +100M -exec du -h {} + 2>/dev/null | sort -h | tail -20

echo ""
echo "=== Project directory size ==="
if [ -d "/home/pi/raspberry-noaa-v2" ]; then
    du -sh /home/pi/raspberry-noaa-v2 2>/dev/null
    echo "Breaking down raspberry-noaa-v2 subdirectories:"
    du -sh /home/pi/raspberry-noaa-v2/* 2>/dev/null | sort -h
fi

echo ""
echo "=== Docker images and containers ==="
if command -v docker &> /dev/null; then
    echo "Docker images:"
    docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" 2>/dev/null
    
    echo ""
    echo "Docker containers (including stopped):"
    docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Size}}" 2>/dev/null
fi

echo ""
echo "=== Checking for USB drives ==="
lsblk 2>/dev/null || echo "lsblk not available, trying df:"
df -h | grep -E "media|mnt|usb" || echo "No USB drives found in standard locations"

