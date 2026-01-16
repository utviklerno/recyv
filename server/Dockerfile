FROM python:3.9-alpine

WORKDIR /app

ENV PYTHONUNBUFFERED=1

COPY app.py .
COPY static ./static

# No external dependencies (using standard library)

CMD ["python", "app.py"]
