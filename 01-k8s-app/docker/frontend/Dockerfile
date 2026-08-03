FROM nginx:alpine
COPY index.html /usr/share/nginx/html/index.html
RUN sed -i 's|/run/nginx.pid|/tmp/nginx.pid|g' /etc/nginx/nginx.conf
RUN chown -R nobody:nobody /var/cache/nginx /var/log/nginx
USER nobody
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]