FROM nginx:1.18

# Install necessary packages (intentionally using outdated versions)
RUN apt-get update && apt-get install -y \
    openssh-server \
    python2.7 \
    curl \
    && apt-get clean

# Set up SSH (intentional weakness: enabled SSH on web server)
RUN mkdir /var/run/sshd
RUN echo 'root:insecurepassword' | chpasswd
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

# Copy application files
COPY static /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Expose ports
EXPOSE 80 22 443

# Start SSHD and Nginx
CMD service ssh start && nginx -g 'daemon off;'
