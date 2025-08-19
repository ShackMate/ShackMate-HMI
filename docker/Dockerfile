FROM php:8.4-apache

# Install Chromium, Xvfb, and Supervisor with additional display support
RUN apt-get update && apt-get install -y \
    chromium \
    xvfb \
    x11-utils \
    x11-xserver-utils \
    xfonts-base \
    xfonts-75dpi \
    xfonts-100dpi \
    supervisor \
    curl \
    dbus-x11 \
    fonts-liberation \
    libasound2 \
    libatk-bridge2.0-0 \
    libdrm2 \
    libxcomposite1 \
    libxdamage1 \
    libxrandr2 \
    libgbm1 \
    libxss1 \
    libnss3 && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Create web root (safety)
RUN mkdir -p /var/www/html

# Copy website files
COPY web/ /var/www/html/
RUN chown -R www-data:www-data /var/www/html

# Copy Supervisor config
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Copy entrypoint
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Copy Chromium startup script
COPY start-chromium.sh /usr/local/bin/start-chromium.sh
RUN chmod +x /usr/local/bin/start-chromium.sh

# Copy UDP listener
COPY udp_listener.py /usr/local/bin/udp_listener.py
RUN chmod +x /usr/local/bin/udp_listener.py

# Expose web port
EXPOSE 80

# Use entrypoint and start Supervisor
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
