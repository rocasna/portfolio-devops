gcloud iam workload-identity-pools create "github-pool" \
  --project="fase-a-504618" \
  --location="global" \
  --display-name="GitHub Actions Pool"

gcloud iam workload-identity-pools providers create-oidc "github-provider" \
  --project="fase-a-504618" \
  --location="global" \
  --workload-identity-pool="github-pool" \
  --display-name="GitHub Provider" \
  --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository" \
  --attribute-condition="assertion.repository=='rocasna/portfolio-devops'" \
  --issuer-uri="https://token.actions.githubusercontent.com"

gcloud projects describe fase-a-504618 --format="value(projectNumber)"

gcloud iam service-accounts add-iam-policy-binding \
  terraform-admin@fase-a-504618.iam.gserviceaccount.com \
  --project="fase-a-504618" \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/projects/1035055063590/locations/global/workloadIdentityPools/github-pool/attribute.repository/rocasna/portfolio-devops"