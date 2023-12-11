FROM python:3.9.17-slim-bookworm

RUN apt-get update && \
    apt-get install -y \
        python3-pip

RUN python -m pip install --upgrade pip && \
    pip install \
        azure-identity \
        azure-keyvault-secrets

COPY get_secret.py .

CMD ["python", "get_secret.py"]
