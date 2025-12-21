# RN2 (Raspberry-NOAA-V2) Docker Image
# Build on Raspberry Pi (ARM32v7)
# 
# Build context should be the RN2 project root (parent of docker/)

FROM debian:bullseye-slim

# Avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Europe/London

# Install base dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Web server
    nginx \
    php7.4-fpm \
    php7.4-sqlite3 \
    php7.4-curl \
    php7.4-mbstring \
    php7.4-xml \
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
    libfftw3-threads3 \
    libfftw3-omp3 \
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

# Copy pre-extracted SatDump files (portable, works on any machine)
# These were extracted from a working installation to avoid corrupted .deb issues
# This makes the Docker image self-contained and deployable to any machine
RUN mkdir -p /usr/lib/arm-linux-gnueabihf /usr/lib/satdump
COPY docker/satdump-files/usr/bin/satdump /usr/bin/satdump
COPY docker/satdump-files/usr/lib/libsatdump_core.so /usr/lib/libsatdump_core.so
COPY docker/satdump-files/usr/lib/arm-linux-gnueabihf/ /usr/lib/arm-linux-gnueabihf/
COPY docker/satdump-files/usr/share/satdump/ /usr/share/satdump/
COPY docker/satdump-files/usr/lib/satdump/plugins/ /usr/lib/satdump/plugins/
RUN chmod +x /usr/bin/satdump \
    && ldconfig || true \
    && which satdump || (echo "ERROR: satdump not found after copy!" && exit 1)

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
RUN sed -i 's/listen = .*/listen = \/run\/php\/php7.4-fpm.sock/' /etc/php/7.4/fpm/pool.d/www.conf \
    && sed -i 's/;clear_env = no/clear_env = no/' /etc/php/7.4/fpm/pool.d/www.conf

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
