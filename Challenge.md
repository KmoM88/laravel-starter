# TierOne DevOps Challenge: Deploy Laravel Hello World to DigitalOcean with Jenkins

## 1. Goal
Deploy the provided Laravel 11 Hello World API as a single Docker container to production on DigitalOcean using a Jenkins CI/CD pipeline. No database, no Docker Compose, no Kubernetes.

## 2. Application Summary
- **Endpoint:** `GET /api/hello`
- **Response:** JSON with message, status, timestamp
- **Tech:** PHP ≥ 8.2, Laravel 11

## 3. Constraints
- Single container only (no Compose, no sidecars)
- No database or external services
- No secrets in the repo—use Jenkins credentials
- Container must run as non-root

## 4. What You Will Build
- Production-ready Docker image for Laravel 11 (multi-stage, optimized, healthcheck)
- Jenkins pipeline that:
  - Checks out code
  - Builds and tags the image `REGISTRY/IMAGE_NAME:<git-sha>` and `:latest`
  - Pushes to a container registry (Docker Hub or DOCR)
  - Deploys to a DigitalOcean Droplet via SSH by stopping the old container and running the new one
  - Health endpoint and basic logs to stdout/stderr
- Documentation (README section) covering setup, deploy, and rollback

## 5. Prerequisites (you may simulate if needed)
- A DigitalOcean Droplet (Ubuntu 22.04+), with Docker installed and SSH access
- A container registry (Docker Hub suggested)
- Jenkins with:
  - docker CLI available on the build agent
  - Credentials:
    - `dockerhub-creds` (username/password) or equivalent
    - `do-ssh-key` (SSH private key for Droplet access)

## 6. Tasks
### A. Containerize the App
- Use a multi-stage Dockerfile (Composer deps in builder; runtime minimal)
- Install and configure php-fpm and nginx
- Serve Laravel from `/public`
- Run the container as a non-root user

### B. Jenkins Pipeline
- Create a declarative Jenkinsfile with stages:
  - Checkout
  - Build Image (tag with short SHA and latest)
  - Login & Push to registry
  - Deploy to Droplet via SSH:
    ```sh
    docker run -d --name hello -p 80:80 \
      -e APP_KEY="$APP_KEY" \
      -e BUILD_SHA=... -e BUILD_AT=... \
      --restart unless-stopped \
      REGISTRY/IMAGE_NAME:SHA
    ```

### C. Documentation
- Update your README with:
  - Architecture (code → image → registry → droplet)
  - Jenkins configuration (credentials IDs, params)
  - Deploy and rollback instructions (redeploy previous tag)

## 7. Acceptance Criteria
- `docker build` succeeds locally and in Jenkins
- Running container serves `GET /api/hello` with 200 JSON
- Jenkins builds, pushes, and deploys the image to the Droplet
- Container runs as non-root and restarts on reboot (`--restart unless-stopped`)
- Clear README with deploy & rollback steps

## 8. What to Submit
- Link to your repository with Dockerfile, Jenkinsfile, and updated README
- Optional: short video screen capture or logs of a successful pipeline run and curl from the Droplet’s public IP

---

# DevOps Challenge — Laravel Hello World

## 1. Docker

### a. Development (`Dockerfile.dev`)
- Used for local development and testing.
- Runs Laravel using the built-in PHP development server.
- Commands:

```sh
docker build -t laravel-dev -f dockerfiles/Dockerfile.dev .
docker run --rm -it -p 8000:8000 laravel-dev
```

### b. Production (`Dockerfile.prod`)
- Multi-stage build: separates dependency installation (Composer builder) from runtime environment (nginx + php-fpm).
- Runs as **non-root**:
  - All processes run under a non-root user where possible.
  - php-fpm and nginx workers run as `www-data`.
- Logging:
  - **Access logs → stdout**
  - **Error logs → stderr**
- Port binding:
  - In the challenge, the requirement was `-p 80:80`.  
  - Binding port 80 directly requires root privileges. To comply with **non-root execution**, the image exposes **port 8080** instead.  
  - Deployment runs as:
    ```sh
    docker run -d -p 80:8080 laravel-prod
    ```
  - If binding `-p 80:80` is mandatory, only nginx/php-fpm **workers** can run as non-root, while the master process still requires root.
- Commands:

```sh
docker build -t laravel-prod -f dockerfiles/Dockerfile.prod .
docker run --rm -it -p 8080:8080 laravel-prod
```

- Configuration files:
  - `nginx/nginx.conf`: nginx configuration to serve the app
  - `nginx/supervisord.conf` (supervisord is used, though migrating to one process per container is recommended for the future due to deprecation of supervisord in the near future)

---

## 2. Jenkins

### a. Local Testing (Jenkins + Local Registry)
- A `docker-compose.yml` is included to spin up:
  - A local Jenkins instance
  - A private Docker Registry
- Allows testing pipelines end-to-end before using DigitalOcean.
- Access:
  - Jenkins: http://localhost:8081 (default: `admin/admin`)
  - Registry: http://localhost:5000
- Commands:

```sh
cd docker-compose
# Create credentials for the registry (only the first time) (sudo apt-get install apache2-utils if you don't have htpasswd):
mkdir -p auth
htpasswd -Bbn testuser testpassword > auth/htpasswd
# Start the services
docker compose up -d
```

### b. Pipelines

#### `Jenkinsfile.test`
- Builds a dummy image (`alpine:3.18`)
- Pushes it to the **local registry**  
- Purpose: test credentials, registry, and connectivity.

#### `Jenkinsfile.local`
- Builds the **Laravel app image** locally.
- Tags with both **SHA** and **latest**.
- Pushes to the **local registry**.

#### `Jenkinsfile.registry`
- Builds the **Laravel app image**.
- Pushes to **DigitalOcean Container Registry (DOCR)**.  
- Requires a **DigitalOcean API token** (generated via the control panel) stored securely in Jenkins credentials.

#### `Jenkinsfile.deploy`
- Builds the image.
- Pushes it to **DOCR**.
- Deploys to a **DigitalOcean droplet** via SSH:
  - Requires a **key pair** uploaded to DigitalOcean.
  - Jenkins uses the private key to connect.
- Steps:
  - Pull new image
  - Stop/remove old container
  - Run new container on port `80:8080`.

#### `Jenkinsfile.rollback`
- Identifies the currently deployed tag.
- Rolls back to the previous image version in the registry.

#### `Jenkinsfile.select-sha`
- Deploys a specific image version.
- Parameterized with a **SHA/tag**.

#### `Jenkinsfile.create-droplet`
- Creates a **droplet named `laravel-deploy`** if it doesn’t already exist.
- Installs Docker automatically on the droplet.
- Leaves the instance ready for deployment.

#### `Jenkinsfile.remove-droplet`
- Deletes the droplet named `laravel-deploy`.

---

## 3. Jenkins Configuration

- The Jenkins image requires instalation of (docker-compose/Dockerfile.jenkins):
  - `doctl` (DigitalOcean CLI)
  - `jq` (for parsing JSON responses)
  - Commands:
    ```sh
    docker build -t jenkins-tierone -f Dockerfile.jenkins .
    docker run -d \
              --name jenkins \
              -u root \
              -p 8080:8080 -p 50000:50000 \
              -v /var/jenkins_home:/var/jenkins_home \
              -v /var/run/docker.sock:/var/run/docker.sock \
              jenkins-tierone:latest
    ```
- Two secrets must be stored in Jenkins credentials:
  1. **DigitalOcean API Token**
  2. **SSH private key** for droplet connection
- The Jenkins user must have access to the Docker daemon (usually by being in the `docker` group).
- TODO: Jenkis must be initialized with the required plugins:
  - Docker Pipeline
  - SSH Agent
  - Credentials Binding
  - Git
  - Pipeline
  - User and Role-based Authorization Strategy (for better security)

---

## 4. Future Improvements

- **Hardcoded values**:
  - Ubuntu release and architecture for Docker installation in droplet.
  - SSH user (`root`).
  - Container/registry/image names.  
  These can be parameterized for multiple environments (dev/test/prod).
- **Remote Jenkins**:
  - Instead of running Jenkins locally, a dedicated droplet could manage pipelines. The image build for the docker compose setup could be pushed to DOCR and used in a remote Jenkins instance. Should add jq and doctl installation steps in the Jenkinsfile.
- **Environment variables**:
  - If the Laravel app required a `.env` file, it could be securely stored in Jenkins and passed during deployment.
- **Infrastructure state management**:
  - Define resources as code using Terraform or similar, storing state in a DO Space/bucket.  
  - For this challenge, using `doctl` inside Jenkins was sufficient and simpler.
- **CI/CD Enhancements**:
  - Add automated tests before building images.
  - Implement health checks with auto-rollback on failed deployments.
  - Deploy the jenkis server with script and spin up the pipelines automaticaly (Load ). 
- **Environments & Testing**:
  - Set up separate environments (staging, production) with different droplets and registries.
  - Implement blue-green deployments or canary releases for zero-downtime updates.
  - Testing pyramid with unit, integration, and end-to-end tests up to stages dev/test/prod/deploy.

---

👉 With this setup, the project provides a **simple but production-ready pipeline** for Laravel on DigitalOcean, while leaving room for scalability and automation improvements.