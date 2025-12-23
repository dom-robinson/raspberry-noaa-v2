# RN2 (Raspberry-NOAA-V2) Docker Image
# Build on Raspberry Pi (ARM64/aarch64) - 64-bit required
# 
# This Dockerfile creates a fully self-contained RN2 container with:
# - All dependencies bundled
# - SatDump compiled from source
# - All tools and libraries included
# - External volumes for data persistence
#
# Build context should be the RN2 project root (parent of docker/)

# Base image: Debian Bookworm (64-bit) for latest RN2 compatibility
FROM debian:bookworm-slim

# Avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Europe/London

# Install base dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Web server
    nginx \
    php8.2-fpm \
    php8.2-sqlite3 \
    php8.2-curl \
    php8.2-mbstring \
    php8.2-xml \
    php8.2-cli \
    # SDR and signal processing
    rtl-sdr \
    librtlsdr-dev \
    libusb-1.0-0 \
    # Image processing
    imagemagick \
    ffmpeg \
    python3 \
    python3-pip \
    python3-numpy \
    python3-pil \
    # Build tools (needed for some pip packages)
    build-essential \
    python3-dev \
    # Scheduling
    at \
    cron \
    # Utilities
    curl \
    wget \
    supervisor \
    sqlite3 \
    bc \
    jq \
    socat \
    netcat-openbsd \
    procps \
    iputils-ping \
    netbase \
    # SatDump dependencies (complete set needed for plugins to work)
    libfftw3-3 \
    libfftw3-single3 \
    libfftw3-bin \
    liborc-0.4-0 \
    libpng16-16 \
    libnng1 \
    librtlsdr0 \
    libzstd1 \
    libjemalloc2 \
    libglfw3 \
    libatomic1 \
    libdeflate0 \
    libgomp1 \
    libjbig0 \
    libjpeg62-turbo \
    liblzma5 \
    libopencl1 \
    libstdc++6 \
    libtiff5 \
    libvolk2.4 \
    libwebp6 \
    libz1 \
    # Clean up
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Upgrade pip first (Bullseye's pip has TOML parsing bugs)
RUN pip3 install --upgrade pip

# Install Python dependencies (numpy and Pillow installed via apt above)
RUN pip3 install --no-cache-dir \
    ephem \
    pytz \
    requests \
    jinja2 \
    pyyaml \
    && python3 -c "import yaml" || (echo "ERROR: pyyaml not installed correctly!" && exit 1)

# Install wkhtmltoimage for annotation generation
RUN apt-get update && apt-get install -y --no-install-recommends \
    wkhtmltopdf \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Create directories
RUN mkdir -p /srv/images /srv/videos /var/log/raspberry-noaa-v2 /run/php \
    && chown -R www-data:www-data /srv/images /srv/videos

# Build SatDump 1.2.2 from source (latest stable for ARM32)
# This ensures a clean, self-contained installation that works reliably
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    build-essential \
    cmake \
    g++ \
    pkgconf \
    libfftw3-dev \
    libpng-dev \
    libtiff-dev \
    libjemalloc-dev \
    libvolk2-dev \
    libnng-dev \
    libcurl4-openssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Clone and build SatDump 1.2.2
RUN cd /tmp && \
    git clone https://github.com/SatDump/SatDump.git satdump-src && \
    cd satdump-src && \
    git checkout 1.2.2 && \
    mkdir build && cd build && \
    cmake -DCMAKE_BUILD_TYPE=Release \
          -DCMAKE_INSTALL_PREFIX=/usr \
          -DBUILD_GUI=OFF \
          -DPLUGIN_AIRSPY_SDR_SUPPORT=OFF \
          -DPLUGIN_AIRSPYHF_SDR_SUPPORT=OFF \
          -DPLUGIN_HACKRF_SDR_SUPPORT=OFF \
          -DPLUGIN_SDRPLAY_SDR_SUPPORT=OFF \
          -DPLUGIN_MIRISDR_SDR_SUPPORT=OFF \
          -DPLUGIN_LIMESDR_SDR_SUPPORT=OFF \
          -DPLUGIN_SDRPP_SERVER_SUPPORT=OFF \
          -DPLUGIN_SPYSERVER_SUPPORT=OFF \
          -DPLUGIN_REMOTE_SDR_SUPPORT=OFF \
          -DPLUGIN_NET_SOURCE_SUPPORT=OFF \
          -DPLUGIN_RTLTCP_SUPPORT=OFF \
          .. && \
    make -j$(nproc) && \
    make install && \
    cd / && \
    find /usr -name satdump -type f 2>/dev/null && \
    ldconfig && \
    test -f /usr/bin/satdump && echo "SatDump installed successfully" || (echo "ERROR: satdump binary not found!" && find /usr -name "*satdump*" && exit 1)

# Create symlinks for libraries that plugins expect in /lib/aarch64-linux-gnu/
# Some plugins hardcode paths to /lib/ instead of /usr/lib/
# Note: 64-bit uses aarch64-linux-gnu instead of arm-linux-gnueabihf
RUN mkdir -p /lib/aarch64-linux-gnu \
    && for lib in libatomic.so.1 libdeflate.so.0 libgomp.so.1 libjbig.so.0 \
                  libjpeg.so.62 libopencl.so.1 libstdc++.so.6 libtiff.so.5 \
                  libvolk.so.2.5 libwebp.so.6 libnng.so.1 libjemalloc.so.2; do \
        if [ -f "/usr/lib/aarch64-linux-gnu/$lib" ] && [ ! -e "/lib/aarch64-linux-gnu/$lib" ]; then \
            ln -sf "/usr/lib/aarch64-linux-gnu/$lib" "/lib/aarch64-linux-gnu/$lib" || true; \
        fi; \
    done

# Clean up build dependencies (keep runtime deps)
RUN apt-get remove -y git build-essential cmake g++ pkgconf libfftw3-dev libpng-dev libtiff-dev libjemalloc-dev libvolk2-dev libnng-dev libcurl4-openssl-dev \
    && apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Copy and install other pre-built ARM packages
COPY raspberry-noaa-v2/software/wxtoimg-armhf*.deb /tmp/wxtoimg.deb
COPY raspberry-noaa-v2/software/predict_*_armhf.deb /tmp/predict.deb

# Install wxtoimg and predict
RUN dpkg -i /tmp/wxtoimg.deb 2>&1 || true \
    && apt-get install -f -y || true \
    && dpkg -i /tmp/predict.deb 2>&1 || true \
    && apt-get install -f -y || true \
    && rm -f /tmp/*.deb \
    && which predict || echo "predict installed"

# Accept wxtoimg license (for root and pi user)
RUN mkdir -p /root/.wxtoimg /home/pi/.wxtoimg \
    && echo "yes" > /root/.wxtoimglic \
    && echo "yes" > /home/pi/.wxtoimglic

# Configure PHP-FPM
RUN sed -i 's/listen = .*/listen = \/run\/php\/php8.2-fpm.sock/' /etc/php/8.2/fpm/pool.d/www.conf \
    && sed -i 's/;clear_env = no/clear_env = no/' /etc/php/8.2/fpm/pool.d/www.conf

# Copy nginx configuration
COPY docker/nginx/rn2.conf /etc/nginx/sites-available/default
RUN rm -f /etc/nginx/sites-enabled/default \
    && ln -sf /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default

# Copy supervisord configuration
COPY docker/supervisord.conf /etc/supervisor/conf.d/rn2.conf

# Copy RN2 application (scripts, migrations, etc)
COPY raspberry-noaa-v2 /opt/raspberry-noaa-v2

# Copy webpanel
COPY wx-new-deployed /var/www/wx-new
RUN chown -R www-data:www-data /var/www/wx-new

# Create pi user for RN2 script compatibility
RUN useradd -m -s /bin/bash pi \
    && usermod -aG plugdev,www-data pi \
    && chown -R pi:pi /home/pi

# Set up RN2 environment
ENV NOAA_HOME=/opt/raspberry-noaa-v2
ENV PATH="${NOAA_HOME}/scripts:${PATH}"
ENV HOME=/home/pi

# Create symlinks expected by RN2 scripts
RUN ln -sf /opt/raspberry-noaa-v2 /home/pi/raspberry-noaa-v2

# Create predict.qth configuration
RUN mkdir -p /home/pi/.predict \
    && echo -e "WRXSEUK-M7MZA\n50.816368\n-0.06511\n30" > /home/pi/.predict/predict.qth \
    && chown -R pi:pi /home/pi/.predict

# Copy .noaa-v2.conf configuration file
COPY docker/config/noaa-v2.conf /home/pi/.noaa-v2.conf
RUN chown pi:pi /home/pi/.noaa-v2.conf

# Create required directories with proper permissions
RUN mkdir -p /srv/audio/noaa /srv/audio/meteor /tmp/ramfs \
    /opt/raspberry-noaa-v2/tmp /opt/raspberry-noaa-v2/db \
    && chown -R pi:pi /srv/audio /tmp/ramfs /opt/raspberry-noaa-v2/tmp \
    && chown -R pi:pi /opt/raspberry-noaa-v2/db || true

# Copy entrypoint script
COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Copy crontab (will be installed in entrypoint)
COPY docker/config/crontab /etc/cron.d/rn2
RUN chmod 0644 /etc/cron.d/rn2

# Expose web port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/ || exit 1

# Start via entrypoint
ENTRYPOINT ["/entrypoint.sh"]
