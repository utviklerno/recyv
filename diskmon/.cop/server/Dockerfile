FROM python:3.9-alpine

WORKDIR /app

COPY app.py .
COPY static ./static

# No external dependencies (using standard library)

CMD ["python", "app.py"]
