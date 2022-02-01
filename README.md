# The Drone Shuttles Ltd. blog

The customer Drone Shuttles Ltd. is currently running their website on an outdated platform
hosted in their own datacenter. They are about to launch a new product that will revolutionize
the market and want to increase their social media presence with a blogging platform. During
their ongoing modernization process, they decided they want to use the Ghost Blog platform
for their marketing efforts.

They do not know what kind of traffic to expect so the solution should be able to adapt to
traffic spikes. It is expected that during the new product launch or marketing campaigns there
could be increases of up to 4 times the typical load. It is crucial that the platform remains
online even in case of a significant geographical failure. The customer is also interested in
disaster recovery capabilities in case of a region failure.

As Ghost will be a crucial part of the marketing efforts, the customer plans to have 5 DevOps
teams working on the project. The teams want to be able to release new versions of the
application multiple times per day, without requiring any downtime. The customer wants to
have multiple separated environments to support their development efforts.
As they are also tasked with maintaining the environment they need tools to support their
operations and help them with visualising and debugging the state of the environment..
The website will be exposed to the internet, thus the security team also needs to have
visibility into the platform and its operations. The customer has also asked for the ability to
delete all posts at once using a serverless function.

## Solution

The blog includes four different environments that are all deployed in the same project. 
The environments are development (dev), testing (test), staging (stage), and production (prod).
Every environment is exactly the same, excluding the machine type and SQL instance tier for 
the staging and production environment to save costs.

Ghost doesn't support load-balanced clustering or multi-server setups of any description,
as described in the FAQ section of the Ghost website: "The recommended approach to achieve scale, performance &
high availability is to put a cache and/or CDN in front of your blog; pages generated by Ghost are essentially
static so there should be very little traffic hitting your Ghost server with a well configured cache."

![Architecture](https://github.com/smorenburg/drone-shuttles-blog/blob/main/images/architecture.png?raw=true)

Ghost is deployed as a container on a single virtual machine instance running Container-Optimized OS 
which is an operating system optimized for running containers. The virtual machine instance is configured using cloud-init.

The virtual machine instance is deployed using a regional managed instance group which supports autohealing and rolling updates.
Whenever the current zone goes down, the instance is recreated in another zone, achieving regional high-availability.
Unfortunately a zonal failure does include some downtime until the failed instance is recreated, this is because of
the Ghost architecture which doesn't support load-balanced clustering or multi-server setups.

Whenever a new container image is created, the image is deployed using a rolling update mechanism. A second instance is
created and will receive all traffic when healthy. The first instance is shut down and removed.

The traffic is managed by a premium global HTTPS load balancer including a managed SSL certificate using a (temporary) 
nip.io domain and a CDN to accommodate large volumes of traffic and low latency around the globe.

The data is persisted in a high-available replicated Cloud SQL instance running MySQL 8.0 using the Cloud SQL Auth Proxy, 
deployed as a container on the virtual machine instance. The Cloud SQL Auth proxy automatically encrypts traffic to and from 
the database using TLS with a 128-bit AES cipher. The master instance is running in the europe-west1 region, located in Belgium, 
whereas the replica instance is running in the europe-north1 region, located in Finland. The database backups are stored in 
the europe-west4 region, located in The Netherlands, to accommodate multiple disaster recovery scenario's.

Whenever there's a complete regional failure the virtual machine instance can be deployed in the europe-north1 region
using the MySQL replica which is read-only by default, with the option to promote the replica instance to a 
single master instance for read-write operations. The subnet for europe-north1 is already present.

The uploaded content is placed in a storage bucket with multi-region availability within Europe. 

By persisting the data and content the Ghost container is completely stateless.

![CI/CD](https://github.com/smorenburg/drone-shuttles-blog/blob/main/images/cicd.png?raw=true)

The deployment is completely automated by using Cloud Build, Artifact Registry, Terraform and Bash. 
The CI/CD pipeline is seperated using multiple triggers and a combination a commit hashes and tags.
The Terraform code and Dockerfile a checked by running Checkov during CI to make sure the best practices are included.
And container scanning is enabled for the registry to scan for vulnerabilities. Every deployment needs manual approval which
can be disabled.

All the assigned permissions follow the principle of least privilege.

The blog is designed for observability. All the metrics and logs are available through the Cloud Operations suite.
There are three SLOs and an uptime check configured:

- 90% of the request are below 250 ms latency 
- 99% of the requests are below 500 ms latency 
- 99% of the requests are successful (availability)

## Prerequisites

Before deploying the blog, there are some prerequisites to fulfill.

**Project:** You need a GCP project with owner permissions
(this is the default for new projects).

**Billing account:** The project needs to be linked with an active billing account.

## Up and running

The following steps are required to prepare the environment and get the blog up and running. The easiest way to execute the
commands is using Cloud Shell, which is already authenticated.

**Step 1:** Set the (local) environment variables. The project id variable is used in some commands.

```bash
export PROJECT_ID=<project_id>
```

**Step 2:** Enable the APIs (services). The following APIs are enabled:

- Cloud Resource Manager API
- Identity and Access Management (IAM) API
- Cloud Build API
- Artifact Registry API
- Container Scanning API
- Compute Engine API
- Cloud SQL Admin API
- Cloud Functions API

```bash
apis=( 
  cloudresourcemanager.googleapis.com
  iam.googleapis.com
  cloudbuild.googleapis.com
  artifactregistry.googleapis.com
  containerscanning.googleapis.com
  compute.googleapis.com
  sqladmin.googleapis.com
  cloudfunctions.googleapis.com
)

for api in "${apis[@]}"; do
  gcloud services enable "${api}" --async
done
```

**Step 3:** Create the storage buckets. The storage buckets are used for the Terraform state separated per environment and the
build artifacts.

```bash
gsutil mb -l eu -b on gs://${PROJECT_ID}-dev-tfstate
gsutil mb -l eu -b on gs://${PROJECT_ID}-test-tfstate
gsutil mb -l eu -b on gs://${PROJECT_ID}-stage-tfstate
gsutil mb -l eu -b on gs://${PROJECT_ID}-prod-tfstate
gsutil mb -l eu -b on gs://${PROJECT_ID}-builds
```

**Step 4:** Create the artifact registries. The 'dev' registry is for the development container images, the 'test' registry
for the testing container images, and the 'release' registry for both the staging and production container images.

```bash
gcloud artifacts repositories create dev \
    --repository-format=docker \
    --location=europe

gcloud artifacts repositories create test \
    --repository-format=docker \
    --location=europe
    
gcloud artifacts repositories create release \
    --repository-format=docker \
    --location=europe 
```

**Step 5:** Delete the default firewall rules and network (if present). The new network conflicts with the default network.

```bash
gcloud compute firewall-rules delete default-allow-icmp default-allow-internal default-allow-rdp default-allow-ssh
gcloud compute networks delete default
```

**Step 6:** Add the roles to the Cloud Build service account. The following roles are added:

- Artifact Registry Writer
- Cloud Functions Admin
- Cloud SQL Admin
- Compute Admin
- Monitoring Admin
- Project IAM Admin
- Secret Manager Admin
- Service Account Admin
- Service Account User
- Storage Admin

```bash
export PROJECT_NUMBER=$(
  gcloud projects list \
    --filter "$(gcloud config get-value project)" \
    --format "value(PROJECT_NUMBER)"
)
  
roles=( 
  roles/artifactregistry.writer
  roles/cloudfunctions.admin
  roles/cloudsql.admin
  roles/compute.admin
  roles/monitoring.admin
  roles/resourcemanager.projectIamAdmin
  roles/secretmanager.admin
  roles/iam.serviceAccountAdmin
  roles/iam.serviceAccountUser
  roles/storage.admin
)

for role in "${roles[@]}"; do
  gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com \
    --role "${role}"
done
```

**Step 7:** Add the source repository. This GitHub repository needs to be added to Cloud Build. Complete the following steps to connect to GitHub:

1. Open the **Triggers** page in the Google Cloud Console.
2. Select your project and click **Open**.
3. Click **Connect Repository**.
4. Select **GitHub (Cloud Build GitHub App)**.
5. Click **Continue**.
6. Authenticate to GitHub.
7. From the list of available repositories, select the desired repository, then click **Connect**.
8. Click **Done**.

**Step 8:** Create the triggers. The triggers are created by importing the trigger YAML files located in `build/triggers`.
The triggers use the configs located in `build/configs`.

```bash
triggers=(
  dev/dev-ci.yaml
  dev/dev-plan.yaml
  dev/dev-cd.yaml
  dev/dev-plan-destroy.yaml
  dev/dev-destroy.yaml
  test/test-ci.yaml
  test/test-plan.yaml
  test/test-cd.yaml
  test/test-plan-destroy.yaml
  test/test-destroy.yaml
  release/release-ci.yaml
  stage/stage-plan.yaml
  stage/stage-cd.yaml
  stage/stage-plan-destroy.yaml
  stage/stage-destroy.yaml
  prod/prod-plan.yaml
  prod/prod-cd.yaml
  prod/prod-plan-destroy.yaml
  prod/prod-destroy.yaml
)

for trigger in "${triggers[@]}"; do
  gcloud beta builds triggers import --source "build/triggers/${trigger}"
done
```

**Step 9:** Deploy the blog to the testing environment. The test-ci trigger is triggered on changes to the main branch, 
with the option for manual invocation.

```bash
gcloud beta builds triggers run test-ci --branch main
```

**Step 10:** Access the blog using the Terraform output. Terraform outputs two URLs: `ghost_url` and `ghost_url_no_cache`.
During the deployment the SSL certificate is assigned to the load balancer. The provisioning of the certificate can take some time
(20 minutes), during the provisioning the blog is not accessible (returns an SSL error).

**Step 11:** Call the function to delete all the posts. Because the function only accepts authenticated HTTP requests, 
gcloud is used for the call.

```bash
gcloud functions call test-posts-ew1-function-delete-all --region europe-west1
```