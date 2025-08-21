FROM php:8.4-apache

# Install essential packages
RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y chromium xinit xterm supervisor curl && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Enable Apache modules and configure
RUN a2enmod rewrite && \
    echo "ServerName localhost" >> /etc/apache2/apache2.conf

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

# Copy UDP listener
COPY udp_listener.py /usr/local/bin/udp_listener.py
RUN chmod +x /usr/local/bin/udp_listener.py

# Expose web port
EXPOSE 80

# Use entrypoint and start Supervisor
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
