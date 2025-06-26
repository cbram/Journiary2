# TravelCompanion Project

This project contains the backend and frontend for the TravelCompanion application.

## Prerequisites

- Docker
- Docker Compose

## Getting Started

To get the development environment up and running, follow these steps:

1.  **Clone the repository:**
    ```sh
    git clone <your-repository-url>
    cd travelcompanion
    ```

2.  **Build and start the services:**

    All services (backend, database, MinIO) are managed via Docker Compose. Use the following command from the project root directory to build and start them:
    ```sh
    docker-compose up --build
    ```
    This will start:
    - The **Backend Server** on `http://localhost:4001`
    - The **PostgreSQL Database** on port `5432` (internal)
    - The **MinIO Server** on `http://localhost:9000` (API) and `http://localhost:9001` (Console)

3.  **Accessing the Services:**
    - **GraphQL API:** `http://localhost:4001/graphql`
    - **MinIO Console:** `http://localhost:9001` (Credentials: `minioadmin`/`minioadmin`)

## Development

The backend source code is located in the `./backend` directory. Thanks to the volume mount in `docker-compose.yml`, any changes you make to the source code will automatically trigger a server restart within the container.

### Running Commands in the Backend Container

To run commands like `npm install` or to run tests inside the backend container, first find the container ID:
```sh
docker ps
```
Then, access the container's shell:
```sh
docker exec -it <backend-container-id> /bin/sh
```
Once inside, you can run your commands, for example:
```sh
npm install some-new-package
``` 