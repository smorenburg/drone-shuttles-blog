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
gcloud config set project $PROJECT_ID
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
)

for i in ${apis[@]}; do
  gcloud services enable $i --async
done
```

#### Create the storage buckets

```bash
gsutil mb -l eur4 -b on gs://$PROJECT_ID-dev-tfstate
gsutil mb -l eur4 -b on gs://$PROJECT_ID-test-tfstate
gsutil mb -l eur4 -b on gs://$PROJECT_ID-stage-tfstate
gsutil mb -l eur4 -b on gs://$PROJECT_ID-prod-tfstate
gsutil mb -l eur4 -b on gs://$PROJECT_ID-builds
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
- Cloud SQL Admin
- Compute Admin
- Monitoring Admin
- Project IAM Admin
- Service Account Admin
- Service Account User
- Storage Admin

```bash
export PROJECT_NUMBER=$(
  gcloud projects list \
    --filter="$(gcloud config get-value project)" \
    --format="value(PROJECT_NUMBER)"
)
  
roles=( 
  roles/artifactregistry.writer
  roles/cloudsql.admin
  roles/compute.admin
  roles/monitoring.admin
  roles/resourcemanager.projectIamAdmin
  roles/iam.serviceAccountAdmin
  roles/iam.serviceAccountUser
  roles/storage.admin
)

for i in ${roles[@]}; do
  gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member=serviceAccount:$PROJECT_NUMBER@cloudbuild.gserviceaccount.com \
    --role=$i
done
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
  build/triggers/dev/dev-ci.yaml
  build/triggers/dev/dev-plan.yaml
  build/triggers/dev/dev-cd.yaml
  build/triggers/dev/dev-destroy.yaml
  build/triggers/test/test-ci.yaml
  build/triggers/test/test-plan.yaml
  build/triggers/test/test-cd.yaml
  build/triggers/test/test-destroy.yaml
  build/triggers/release/release-ci.yaml
  build/triggers/stage/stage-plan.yaml
  build/triggers/stage/stage-cd.yaml
  build/triggers/stage/stage-destroy.yaml
  build/triggers/prod/prod-plan.yaml
  build/triggers/prod/prod-cd.yaml
  build/triggers/prod/prod-destroy.yaml
)

for i in "${triggers[@]}"; do
  gcloud beta builds triggers import --source "$i"
done
```