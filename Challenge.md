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

#### `Jenkinsfile.health-check`
- Checks the health of the deployed container and if it's unhealthy deploys a stable (latest) container.

---

## 3. Jenkins Configuration

For deploying Jenkins, follow these steps:

1. **Create Droplet**
   Run `scripts/01-create-droplet.sh` to launch a new DigitalOcean instance.

2. **Setup Droplet**
   Run `scripts/02-setup-droplet.sh` to install Docker and the tools required for the Jenkins image.

3. **Deploy Jenkins**
   Run `scripts/03-deploy-jenkins.sh` which will copy `docker-compose/Dockerfile.jenkins` to the droplet, build the Jenkins Docker image, and run the container:

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

4. **Initial Jenkins Setup (Manual)**

   * Set the admin password.
   * Install default plugins.
   * Create admin user `tierone`.
   * Add credentials: `DO-token` and `do-ssh-key`.
   * Generate an API token to allow pipeline uploads via the Jenkins API.

5. **Generate Job Configs**
   Run `scripts/04-gen-configs.py` to generate XML files from Jenkinsfiles located in the Jenkins path.
   Usage:
   ```sh
    python 04-gen_configs.py \
    --repo "https://github.com/tu-org/tu-repo.git" \
    --branch "main" \
    --path ../Jenkins/
    ```

6. **Clean Unnecessary XML**
   Delete any XML files that are not needed.

7. **Create Jenkins Jobs**
   Run `scripts/05-create-jobs.py` to load the pipelines into Jenkins.
   Usage:
   ```sh
   python 05-create_jobs.py http://<JENKINS_IP>:<PORT> <USER> <API_TOKEN> ../Jenkins/
    ```

## Recommendations

* Always back up your Jenkins configuration.
* Use a persistent volume (`/var/jenkins_home`) to avoid reconfiguring Jenkins each time the container is restarted.
* Ensure the Jenkins container user has access to the Docker daemon.
* Manual setup steps are only required for the initial deployment and credential/API key setup.
* Separate Jenkins server and agents to improve security and scalability.


---
## 5. Billing / Test Resources

### Laravel App Droplet
- **Plan:** DigitalOcean Droplet $4/month (smallest available)
- **Purpose:** Host Laravel application
- **Tests performed:**
  - [x] k6 load test results (from one source IP)
  
  Results from k6s from local (k6s/load-test.js):
  
  - smoke 150:
    - Report k6s:
    ```sh
      █ TOTAL RESULTS 

        HTTP
        http_req_duration..............: avg=315.97ms min=204.93ms med=261.69ms max=1.28s p(90)=449.9ms p(95)=733.08ms
          { expected_response:true }...: avg=315.97ms min=204.93ms med=261.69ms max=1.28s p(90)=449.9ms p(95)=733.08ms
        http_req_failed................: 0.00%  0 out of 1744
        http_reqs......................: 1744   107.617703/s

        EXECUTION
        iteration_duration.............: avg=1.33s    min=1.2s     med=1.26s    max=2.52s p(90)=1.46s   p(95)=1.92s   
        iterations.....................: 1744   107.617703/s
        vus............................: 15     min=15        max=150
        vus_max........................: 150    min=150       max=150

        NETWORK
        data_received..................: 614 kB 38 kB/s
        data_sent......................: 140 kB 8.6 kB/s




    running (16.2s), 000/150 VUs, 1744 complete and 0 interrupted iterations
    smoke_test_150 ✓ [======================================] 150 VUs  15s
    ```

  - smoke 250:
    - Report k6s:
    ```sh
      █ TOTAL RESULTS 

        HTTP
        http_req_duration..............: avg=918.65ms min=236.7ms med=881.33ms max=2.23s p(90)=1.06s p(95)=1.36s
          { expected_response:true }...: avg=918.65ms min=236.7ms med=881.33ms max=2.23s p(90)=1.06s p(95)=1.36s
        http_req_failed................: 0.00%  0 out of 2045
        http_reqs......................: 2045   120.761606/s

        EXECUTION
        iteration_duration.............: avg=1.94s    min=1.44s   med=1.88s    max=3.51s p(90)=2.08s p(95)=2.6s 
        iterations.....................: 2045   120.761606/s
        vus............................: 122    min=122       max=250
        vus_max........................: 250    min=250       max=250

        NETWORK
        data_received..................: 720 kB 43 kB/s
        data_sent......................: 164 kB 9.7 kB/s
    ```

  - smoke 375:
    - Report k6s:
    ```sh
      █ TOTAL RESULTS 

        HTTP
        http_req_duration..............: avg=1.43s min=225.43ms med=1.54s max=2.2s  p(90)=1.88s p(95)=1.93s
          { expected_response:true }...: avg=1.49s min=225.43ms med=1.54s max=2.2s  p(90)=1.89s p(95)=1.93s
        http_req_failed................: 4.86%  113 out of 2325
        http_reqs......................: 2325   130.026392/s

        EXECUTION
        iteration_duration.............: avg=2.63s min=1.42s    med=2.72s max=3.84s p(90)=3.09s p(95)=3.14s
        iterations.....................: 2325   130.026392/s
        vus............................: 101    min=101         max=375
        vus_max........................: 375    min=375         max=375

        NETWORK
        data_received..................: 779 kB 44 kB/s
        data_sent......................: 199 kB 11 kB/s




    running (17.9s), 000/375 VUs, 2325 complete and 0 interrupted iterations
    smoke_test_375 ✓ [======================================] 375 VUs  15s
    ```

  - smoke 450:
    - Report k6s:
    ```sh
      █ TOTAL RESULTS 

        HTTP
        http_req_duration..............: avg=1.63s min=198.69ms med=1.95s max=2.47s p(90)=2.26s p(95)=2.29s
          { expected_response:true }...: avg=1.9s  min=278.3ms  med=1.97s max=2.47s p(90)=2.28s p(95)=2.29s
        http_req_failed................: 16.22% 424 out of 2614
        http_reqs......................: 2614   143.644044/s

        EXECUTION
        iteration_duration.............: avg=2.84s min=1.39s    med=3.16s max=3.59s p(90)=3.46s p(95)=3.49s
        iterations.....................: 2614   143.644044/s
        vus............................: 31     min=31          max=450
        vus_max........................: 450    min=450         max=450

        NETWORK
        data_received..................: 771 kB 42 kB/s
        data_sent......................: 212 kB 12 kB/s




    running (18.2s), 000/450 VUs, 2614 complete and 0 interrupted iterations
    smoke_test_450 ✓ [======================================] 450 VUs  15s
    ```

  - stress test 150:
    - Report k6s:
    ```sh
      █ TOTAL RESULTS 

        HTTP
        http_req_duration..............: avg=289.02ms min=202.98ms med=226.83ms max=857.56ms p(90)=475.44ms p(95)=602.37ms
          { expected_response:true }...: avg=289.02ms min=202.98ms med=226.83ms max=857.56ms p(90)=475.44ms p(95)=602.37ms
        http_req_failed................: 0.00%  0 out of 7600
        http_reqs......................: 7600   84.086912/s

        EXECUTION
        iteration_duration.............: avg=793.77ms min=703.8ms  med=728.72ms max=1.35s    p(90)=981.5ms  p(95)=1.1s    
        iterations.....................: 7600   84.086912/s
        vus............................: 3      min=1         max=149
        vus_max........................: 150    min=150       max=150

        NETWORK
        data_received..................: 2.7 MB 30 kB/s
        data_sent......................: 608 kB 6.7 kB/s




    running (1m30.4s), 000/150 VUs, 7600 complete and 0 interrupted iterations
    stress_test_150 ✓ [======================================] 000/150 VUs  1m30s
    ```

  - stress test 250:
    - Report k6s:
    ```sh
      █ TOTAL RESULTS 

        HTTP
        http_req_duration..............: avg=629.73ms min=203.43ms med=617.92ms max=1.53s p(90)=1.16s p(95)=1.27s
          { expected_response:true }...: avg=629.73ms min=203.43ms med=617.92ms max=1.53s p(90)=1.16s p(95)=1.27s
        http_req_failed................: 0.00%  0 out of 10007
        http_reqs......................: 10007  110.551677/s

        EXECUTION
        iteration_duration.............: avg=1.13s    min=704.02ms med=1.12s    max=2.15s p(90)=1.67s p(95)=1.78s
        iterations.....................: 10007  110.551677/s
        vus............................: 4      min=3          max=249
        vus_max........................: 250    min=250        max=250

        NETWORK
        data_received..................: 3.5 MB 39 kB/s
        data_sent......................: 801 kB 8.8 kB/s




    running (1m30.5s), 000/250 VUs, 10007 complete and 0 interrupted iterations
    stress_test_250 ✓ [======================================] 000/250 VUs  1m30s

    kmom@ASUS-F15 /media/kmom/Data/SSDATA/github/kmom88/laravel-starter/k6s
    ```

  - stress test 375:
    - Report k6s:
    ```sh
      █ TOTAL RESULTS 

        HTTP
        http_req_duration..............: avg=1.02s min=199.6ms  med=1.05s max=2.96s p(90)=1.87s p(95)=1.99s
          { expected_response:true }...: avg=1.02s min=204.04ms med=1.05s max=2.96s p(90)=1.87s p(95)=1.99s
        http_req_failed................: 0.23%  26 out of 10973
        http_reqs......................: 10973  121.145611/s

        EXECUTION
        iteration_duration.............: avg=1.56s min=704.46ms med=1.55s max=3.79s p(90)=2.52s p(95)=2.66s
        iterations.....................: 10973  121.145611/s
        vus............................: 7      min=4           max=374
        vus_max........................: 375    min=375         max=375

        NETWORK
        data_received..................: 3.9 MB 43 kB/s
        data_sent......................: 934 kB 10 kB/s




    running (1m30.6s), 000/375 VUs, 10973 complete and 0 interrupted iterations
    stress_test_375 ✓ [======================================] 000/375 VUs  1m30s
    ```

  - stress test 600:
    - Report k6s:
    ```sh
          █ TOTAL RESULTS 

        HTTP
        http_req_duration..............: avg=1.05s min=197.91ms med=341.53ms max=3.61s p(90)=2.56s p(95)=2.66s
          { expected_response:true }...: avg=1.36s min=203.57ms med=1.26s    max=3.61s p(90)=2.61s p(95)=2.69s
        http_req_failed................: 27.08% 3737 out of 13795
        http_reqs......................: 13795  122.674325/s

        EXECUTION
        iteration_duration.............: avg=1.67s min=704.29ms med=919.72ms max=4.43s p(90)=3.26s p(95)=3.37s
        iterations.....................: 13795  122.674325/s
        vus............................: 1      min=1             max=599
        vus_max........................: 600    min=600           max=600

        NETWORK
        data_received..................: 3.5 MB 32 kB/s
        data_sent......................: 1.1 MB 10 kB/s




    running (1m52.5s), 000/600 VUs, 13795 complete and 1 interrupted iterations
    stress_test_375 ✓ [======================================] 000/600 VUs  1m30s
    
    ```

### Jenkins Instance
- **Plan:** DigitalOcean Droplet ($18–24/month, can be fine-tuned)
- **Purpose:** CI/CD orchestration

### Volume
- **Plan:** DigitalOcean Block Storage Volume $10/month
- **Purpose:** Persistent storage for data/logs

### Container Registry
- **Plan:** DigitalOcean Container Registry (Free Tier)
- **Purpose:** Store Docker images
- **Usage:** 427MB/500MB (37 Images)

---

## 5. Future Improvements

- **Hardcoded values**:
  - Ubuntu release and architecture for Docker installation in droplet.
  - SSH user (`root`).
  - Container/registry/image names.  
  These can be parameterized for multiple environments (dev/test/prod).
- **Environment variables**:
  - If the Laravel app required a `.env` file, it could be securely stored in Jenkins and passed during deployment.
- **Infrastructure state management**:
  - Define resources as code using Terraform or similar, storing state in a DO Space/bucket.  
  - For this challenge, using `doctl` inside Jenkins was sufficient and simpler.
- **CI/CD Enhancements**:
  - Add automated tests after building images.
- **Environments & Testing**:
  - Set up separate environments (staging, production) with different droplets and registries.
  - Implement blue-green deployments or canary releases for zero-downtime updates.
  - Testing pyramid with unit, integration, and end-to-end tests up to stages dev/test/prod/deploy.
- **DO Droplet Image for App**:
  - Ubuntu 22.04 was used with least resources available on NYC3 region (1vCPU, 1GB RAM, 25GB SSD, $4/month).

---

👉 With this setup, the project provides a **simple but production-ready pipeline** for Laravel on DigitalOcean, while leaving room for scalability and automation improvements.