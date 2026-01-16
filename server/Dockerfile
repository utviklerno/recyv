FROM python:3.9-alpine

WORKDIR /app

# Install OpenSSH Server and curl
RUN apk add --no-cache openssh curl

# Create recyv user
RUN adduser -D -s /bin/sh recyv \
    && mkdir -p /home/recyv/.ssh \
    && chmod 700 /home/recyv/.ssh \
    && chown recyv:recyv /home/recyv/.ssh

# Unlock recyv user
RUN passwd -u recyv

COPY app.py .
COPY static ./static
COPY receive_data.sh .

RUN chmod +x receive_data.sh

# Setup entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENV PYTHONUNBUFFERED=1

EXPOSE 8080 2222

CMD ["/entrypoint.sh"]
