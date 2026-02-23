# Documenso NAS Deployment Guide

This guide describes how to deploy Documenso on a NAS using Docker Compose and Postgres, based on the provided documentation.

## Prerequisites

- A NAS or server with Docker and Docker Compose installed.
- A valid domain name pointing to your NAS (for production use) or a local IP address.
- A digital signing certificate (`cert.p12`) if you plan to use local signing.

## Stack Overview

The stack consists of two services:
1.  **Postgres (v16)**: The database for Documenso.
2.  **Documenso (latest)**: The application server.

## Deployment Steps

### 1. Create a Project Directory

Create a directory on your NAS for the project, e.g., `documenso-docker`.

### 2. Prepare the `docker-compose.yml`

Create a `docker-compose.yml` file in the directory with the following content. This configuration improves upon the original example by including missing environment variables necessary for email and signing.

```yaml
version: '3.8'

services:
  postgres:
    image: postgres:16
    restart: always
    environment:
      POSTGRES_USER: ${POSTGRES_USER:-documenso}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-changeme}
      POSTGRES_DB: ${POSTGRES_DB:-documenso}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER:-documenso} -d ${POSTGRES_DB:-documenso}"]
      interval: 10s
      timeout: 5s
      retries: 5

  documenso:
    image: documenso/documenso:latest
    restart: always
    ports:
      - "3000:3000"
    environment:
      # Core Application
      NEXTAUTH_SECRET: ${NEXTAUTH_SECRET}
      NEXTAUTH_URL: ${NEXT_PUBLIC_WEBAPP_URL}
      NEXT_PUBLIC_WEBAPP_URL: ${NEXT_PUBLIC_WEBAPP_URL}
      NEXT_PRIVATE_INTERNAL_WEBAPP_URL: http://localhost:3000

      # Database
      NEXT_PRIVATE_DATABASE_URL: postgres://${POSTGRES_USER:-documenso}:${POSTGRES_PASSWORD:-changeme}@postgres:5432/${POSTGRES_DB:-documenso}
      NEXT_PRIVATE_DIRECT_DATABASE_URL: postgres://${POSTGRES_USER:-documenso}:${POSTGRES_PASSWORD:-changeme}@postgres:5432/${POSTGRES_DB:-documenso}

      # Encryption (32 chars)
      NEXT_PRIVATE_ENCRYPTION_KEY: ${NEXT_PRIVATE_ENCRYPTION_KEY}
      NEXT_PRIVATE_ENCRYPTION_SECONDARY_KEY: ${NEXT_PRIVATE_ENCRYPTION_SECONDARY_KEY}

      # Email/SMTP
      NEXT_PRIVATE_SMTP_TRANSPORT: ${NEXT_PRIVATE_SMTP_TRANSPORT:-smtp-auth}
      NEXT_PRIVATE_SMTP_HOST: ${NEXT_PRIVATE_SMTP_HOST}
      NEXT_PRIVATE_SMTP_PORT: ${NEXT_PRIVATE_SMTP_PORT:-587}
      NEXT_PRIVATE_SMTP_USERNAME: ${NEXT_PRIVATE_SMTP_USERNAME}
      NEXT_PRIVATE_SMTP_PASSWORD: ${NEXT_PRIVATE_SMTP_PASSWORD}
      NEXT_PRIVATE_SMTP_SECURE: ${NEXT_PRIVATE_SMTP_SECURE:-true}
      NEXT_PRIVATE_SMTP_FROM_NAME: ${NEXT_PRIVATE_SMTP_FROM_NAME:-Documenso}
      NEXT_PRIVATE_SMTP_FROM_ADDRESS: ${NEXT_PRIVATE_SMTP_FROM_ADDRESS}

      # Signing (Local)
      NEXT_PRIVATE_SIGNING_TRANSPORT: local
      NEXT_PRIVATE_SIGNING_LOCAL_FILE_PATH: /app/cert.p12
      NEXT_PRIVATE_SIGNING_PASSPHRASE: ${NEXT_PRIVATE_SIGNING_PASSPHRASE}

    depends_on:
      postgres:
        condition: service_healthy
    volumes:
      - ./cert.p12:/app/cert.p12:ro

volumes:
  postgres_data:
```

### 3. Create an `.env` file

Create an `.env` file in the same directory to store your secrets and configuration. **This is mandatory for security.**

```env
# Database
POSTGRES_USER=documenso
POSTGRES_PASSWORD=secure_database_password
POSTGRES_DB=documenso

# Application
# Generate a random string: openssl rand -base64 32
NEXTAUTH_SECRET=your_nextauth_secret_here
# The URL where your app will be accessible
NEXT_PUBLIC_WEBAPP_URL=http://your-nas-ip:3000

# Encryption Keys (Must be 32 characters exactly)
NEXT_PRIVATE_ENCRYPTION_KEY=12345678901234567890123456789012
NEXT_PRIVATE_ENCRYPTION_SECONDARY_KEY=12345678901234567890123456789012

# SMTP Configuration (Required for emails)
NEXT_PRIVATE_SMTP_TRANSPORT=smtp-auth
NEXT_PRIVATE_SMTP_HOST=smtp.gmail.com
NEXT_PRIVATE_SMTP_PORT=587
NEXT_PRIVATE_SMTP_USERNAME=your_email@gmail.com
NEXT_PRIVATE_SMTP_PASSWORD=your_app_password
NEXT_PRIVATE_SMTP_FROM_ADDRESS=your_email@gmail.com
NEXT_PRIVATE_SMTP_SECURE=true

# Signing Configuration
NEXT_PRIVATE_SIGNING_PASSPHRASE=your_certificate_password
```

### 4. Provide the Certificate

You must place a valid PKCS#12 certificate file named `cert.p12` in the project directory. This file is mounted into the container at `/app/cert.p12`.

### 5. Start the Stack

Run the following command to start the services:

```bash
docker-compose up -d
```

### 6. Run Database Migrations

**Important:** After the containers are up and running, you must run the database migrations manually.

```bash
docker-compose exec documenso npm run prisma:migrate-deploy
```

## Mandatory Environment Variables

The following environment variables are **mandatory** for the application to function correctly:

| Variable | Description |
| :--- | :--- |
| `NEXTAUTH_SECRET` | Used to encrypt session tokens. |
| `NEXT_PUBLIC_WEBAPP_URL` | The public URL of your Documenso instance. |
| `NEXT_PRIVATE_DATABASE_URL` | Connection string for the Postgres database. |
| `NEXT_PRIVATE_DIRECT_DATABASE_URL` | Direct connection string for the Postgres database. |
| `NEXT_PRIVATE_ENCRYPTION_KEY` | 32-character key for data encryption. |
| `NEXT_PRIVATE_ENCRYPTION_SECONDARY_KEY` | 32-character secondary key for data encryption. |
| `NEXT_PRIVATE_SMTP_*` | All SMTP variables are required to send emails (invitations, notifications). |
| `NEXT_PRIVATE_SIGNING_*` | Required if you want to sign documents. |

## Missing Files & Clarifications

Based on the review of the repository and the attached docker compose snippet:

1.  **Missing Files**:
    -   `cert.p12`: The docker-compose example assumes this file exists in the current directory (`./cert.p12`). It is required for the signing functionality.
    -   `.env`: The example uses hardcoded values or omits sensitive variables. Using an `.env` file is best practice.

2.  **Secrets**:
    -   **Encryption Keys**: `NEXT_PRIVATE_ENCRYPTION_KEY` and `NEXT_PRIVATE_ENCRYPTION_SECONDARY_KEY` **must** be exactly 32 characters long.
    -   **Passwords**: Database password, SMTP password, and Signing Certificate passphrase are secrets that should be handled carefully.

3.  **Volumes**:
    -   `postgres_data`: This volume is correctly defined to persist database data.
    -   `./cert.p12`: This bind mount is required for the application to access the signing certificate.

4.  **SMTP Configuration**:
    -   The original `docker-compose.yml` snippet was missing several SMTP variables (`USERNAME`, `PASSWORD`, `FROM_ADDRESS`, `SECURE`) which are present in the `docker run` example. These have been added to the recommended configuration above.

5.  **Signing Configuration**:
    -   The original snippet mounted the certificate but didn't set the `NEXT_PRIVATE_SIGNING_PASSPHRASE` or `NEXT_PRIVATE_SIGNING_TRANSPORT` environment variables. These have been added.
