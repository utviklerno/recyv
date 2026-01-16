FROM python:3.9-alpine

WORKDIR /app

# Install OpenSSH Server and curl
RUN apk add --no-cache openssh curl

# Create diskmon user
RUN adduser -D -s /bin/sh diskmon \
    && mkdir -p /home/diskmon/.ssh \
    && chmod 700 /home/diskmon/.ssh \
    && chown diskmon:diskmon /home/diskmon/.ssh

# Unlock diskmon user (needed for key auth sometimes depending on PAM, but usually fine)
RUN passwd -u diskmon

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
