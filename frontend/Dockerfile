FROM nginx:1.28-alpine

RUN rm -f /etc/nginx/conf.d/default.conf

COPY nginx.conf /etc/nginx/nginx.conf
COPY --chown=101:101 index.html app.js config.js styles.css /usr/share/nginx/html/

USER 101:101

EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]
