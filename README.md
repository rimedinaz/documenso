# Documenso Standalone Stack for NAS

This repository provides a standalone Docker Compose stack for running Documenso and Postgres on a NAS or local environment.

## Prerequisites

- Docker
- Docker Compose
- OpenSSL (usually available on most Linux distros)

## Quick Start

1.  **Initialize the Environment**

    Run the initialization script to generate environment variables, encryption keys, and a self-signed certificate.

    ```bash
    bash init.sh
    ```

    This will create a `.env` file and a `certs/cert.p12` file.

2.  **Start the Stack**

    Start the containers in the background.

    ```bash
    docker-compose up -d
    ```

3.  **Run Database Migrations**

    Wait for the containers to start (check `docker-compose logs -f documenso` if needed), then run the database migrations. This step is crucial for the application to work.

    ```bash
    docker-compose exec documenso npm run prisma:migrate-deploy
    ```

    Note: The `documenso` container might restart a few times initially while waiting for Postgres to be ready. This is normal.

## Accessing the Application

- **Documenso**: [http://localhost:3000](http://localhost:3000)
- **Mailpit (Email Capture)**: [http://localhost:8025](http://localhost:8025)

## Configuration

The configuration is managed via the `.env` file. You can modify it to change ports, database credentials, or other settings.

### Key Variables

- `PORT`: Application port (default: 3000)
- `POSTGRES_USER`: Database user
- `POSTGRES_PASSWORD`: Database password
- `NEXT_PUBLIC_UPLOAD_TRANSPORT`: Storage backend (default: `database`). Change to `s3` if using an external S3 provider.

## Troubleshooting

- **Container keeps restarting**: Check logs with `docker-compose logs -f documenso`. It might be waiting for the database or missing environment variables.
- **Database connection error**: Ensure the `postgres` service is healthy and the credentials in `.env` match `docker-compose.yml`.
- **Permission denied**: Ensure `init.sh` has execute permissions (`chmod +x init.sh`) and that the `certs` directory is writable.

## Storage Note

By default, this stack uses database storage (if supported) or local file system storage for uploads. If you require S3 compatibility, you can add a MinIO service to `docker-compose.yml` and update `.env` accordingly.
