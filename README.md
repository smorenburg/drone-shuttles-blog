# The Drone Shuttles Ltd. blog

## Up and running

The following steps are required to prepare the environment and get the service up and running.

### Prerequisites

### Environment

#### Set the (local) environment variables

```bash
export PROJECT_ID=<project_id>
```

#### Authenticate and configure gcloud

```bash
gcloud auth login
gcloud config set project ${PROJECT_ID}
```

#### Enable the APIs (services)

```bash
apis=( 
  cloudresourcemanager.googleapis.com
  iam.googleapis.com
  secretmanager.googleapis.com
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

#### Create the storage buckets

```bash
gsutil mb -l eur4 -b on gs://${PROJECT_ID}-dev-tfstate
gsutil mb -l eur4 -b on gs://${PROJECT_ID}-test-tfstate
gsutil mb -l eur4 -b on gs://${PROJECT_ID}-stage-tfstate
gsutil mb -l eur4 -b on gs://${PROJECT_ID}-prod-tfstate
gsutil mb -l eur4 -b on gs://${PROJECT_ID}-builds
```

#### Create the artifact registries

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

#### Delete the default firewall rules and network (if present)

```bash
gcloud compute firewall-rules delete default-allow-icmp default-allow-internal default-allow-rdp default-allow-ssh
gcloud compute networks delete default
```

### Cloud Build

#### Add the roles to the service account

The following roles are added:

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

#### Create the Pub/Sub topic

```bash
gcloud pubsub topics create cloud-builds
```

#### Add the source repository

Complete the following steps to connect to GitHub:

1. Open the **Triggers** page in the Google Cloud Console.
2. Select your project and click **Open**.
3. Click **Connect Repository**.
4. Select **GitHub (Cloud Build GitHub App)**.
5. Click **Continue**.
6. Authenticate to GitHub.
7. From the list of available repositories, select the desired repository, then click **Connect**.
8. Click **Done**.

#### Create the triggers

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

## Usage

### Invoke the function

```bash
gcloud functions call posts-delete-all-function --region europe-west1
```