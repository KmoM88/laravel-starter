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
    docker pull REGISTRY/IMAGE_NAME:SHA
    docker stop hello || true && docker rm hello || true
    docker run -d --name hello -p 80:80 \
      -e APP_ENV=production \
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


# Solution: Generated Files

## 1. Dockerfile.dev (for local testing)
- Enables local development and testing using Laravel's built-in server.
- Commands:
  ```sh
  docker build -t laravel-dev -f dockerfiles/Dockerfile.dev .
  docker run --rm -it -p 8000:8000 laravel-dev
  ```
## 2. Dockerfile.prod and configuration files
- Multi-stage: separates dependency installation (builder) from the runtime environment, resulting in a smaller and more secure image.
- Includes nginx and php-fpm configuration to serve Laravel from `/public`.
- **Non-root execution:** The container is designed so that php-fpm and nginx worker processes run as the non-root user `www-data`, while the nginx master process starts as root (required to bind to port 80) and then drops privileges. This setup meets the challenge requirement of not running the application as root, while ensuring nginx can function properly in a containerized environment.
- Commands:
  ```sh
  docker build -t laravel-prod -f dockerfiles/Dockerfile.prod .
  docker run --rm -it -p 8080:80 laravel-prod
  ```

- Configuration files:
  - `nginx/nginx.conf`: nginx configuration to serve the app (includes `user www-data;` for non-root workers)
  - `nginx/supervisord.conf` (if supervisor is used, though migrating to one process per container is recommended for the future)

---

## 3. Local Testing: Jenkins and Docker Registry

To test the pipeline locally before deploying to DigitalOcean, you can spin up a Jenkins server and a private Docker Registry using docker-compose:

```sh
cd docker-compose
# Create credentials for the registry (only the first time):
mkdir -p auth
htpasswd -Bbn testuser testpassword > auth/htpasswd
# Start the services
docker compose up -d
```

Available services:
- Jenkins: http://localhost:8081 (admin/admin)
- Docker Registry: http://localhost:5000 (user: testuser, pass: testpassword)

This will allow you to test building and pushing images from Jenkins to a local private registry.