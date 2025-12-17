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
    jinja2

# Create directories
RUN mkdir -p /srv/images /srv/videos /var/log/raspberry-noaa-v2 /run/php \
    && chown -R www-data:www-data /srv/images /srv/videos

# Copy and install pre-built ARM packages
# These .deb files are for armhf architecture
COPY raspberry-noaa-v2/software/satdump_*_armhf.deb /tmp/satdump.deb
COPY raspberry-noaa-v2/software/wxtoimg-armhf*.deb /tmp/wxtoimg.deb
COPY raspberry-noaa-v2/software/predict_*_armhf.deb /tmp/predict.deb

RUN dpkg -i /tmp/satdump.deb 2>/dev/null; apt-get install -f -y || true \
    && dpkg -i /tmp/wxtoimg.deb 2>/dev/null; apt-get install -f -y || true \
    && dpkg -i /tmp/predict.deb 2>/dev/null; apt-get install -f -y || true \
    && rm -f /tmp/*.deb

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

# Copy entrypoint script
COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Expose web port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/ || exit 1

# Start via entrypoint
ENTRYPOINT ["/entrypoint.sh"]
