# Nordcloud: Blog assignment

### General

#### Create the environment variables

```bash
export PROJECT_ID=project_id
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
  cloudkms.googleapis.com
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

#### Create the registries

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

#### Delete the default firewall rules and default network

```bash
gcloud compute firewall-rules delete default-allow-icmp default-allow-internal default-allow-rdp default-allow-ssh
gcloud compute networks delete default
```

### Cloud Build

#### Add the roles to the Cloud Build service account

The following roles are added:

- Artifact Registry Writer

```bash
export PROJECT_NUMBER=$(
    gcloud projects list \
    --filter="$(gcloud config get-value project)" \
    --format="value(PROJECT_NUMBER)"
)

gcloud projects add-iam-policy-binding $PROJECT_ID \
        --member=serviceAccount:$PROJECT_NUMBER@cloudbuild.gserviceaccount.com \
        --role=roles/owner
```

#### Add the repository to Cloud Build

Describe the steps.

#### Create the Cloud Build triggers

```bash
# Write code.
```