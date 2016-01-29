FROM nginx:1.9.5

# Set the default timezone to Shanghai
RUN echo "Asia/Shanghai" > /etc/timezone
RUN dpkg-reconfigure -f noninteractive tzdata

COPY nginx.conf /etc/nginx/nginx.conf
