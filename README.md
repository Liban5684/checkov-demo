# Checkov Demo Repository (Repo A)

A sample IaC repository used to demonstrate [Checkov](https://www.checkov.io/)
scanning via a **reusable composite action** hosted in a separate repository
(Repo B: `checkov-reusable-action`), and to test the **Snyk visibility gap**
for packages installed by that action.

## Structure

```
.
├── .github/
│   └── workflows/
│       └── checkov.yml         # CI: runs Checkov via Repo B + Snyk test
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── provider.tf
│   └── modules/
│       ├── s3/main.tf          # Has intentional findings
│       └── ec2/main.tf         # Has intentional findings
├── kubernetes/
│   └── deployment.yaml         # Has intentional findings
├── .checkov.baseline           # Suppresses pre-existing CKV_AWS_18
└── .checkov.yaml               # Local Checkov config
```

## What this tests

The `snyk-visibility-test` job in `checkov.yml` answers a specific question:

> **Does Snyk, running in Repo A, detect Python packages installed by a
> reusable action sourced from Repo B?**

The test works as follows:

1. The reusable action (from Repo B) installs `checkov==3.1.0` on the runner
   using its own `requirements.txt` — which lives at `$GITHUB_ACTION_PATH`,
   **outside** the caller's `$GITHUB_WORKSPACE`.
2. A diagnostic step shows what `pip list` returns — proving the packages
   ARE on the runner.
3. Snyk then scans `$GITHUB_WORKSPACE` — and finds **no Python manifest**,
   because Repo B's `requirements.txt` was never checked out here.
4. The expected result: Snyk reports nothing for Python, confirming the gap.

## Setup

1. Push **Repo B** (`checkov-reusable-action`) to GitHub under your org.
2. Replace `YOUR_ORG` in `.github/workflows/checkov.yml` with your GitHub
   organisation or username.
3. Add a `SNYK_TOKEN` repository secret (Settings → Secrets → Actions).
4. Push this repo — the workflow triggers automatically.

## Intentional Checkov Findings

| Resource | Check ID | Issue |
|----------|----------|-------|
| `aws_s3_bucket.logs` | CKV_AWS_20 | Bucket is publicly readable |
| `aws_s3_bucket.logs` | CKV_AWS_52 | MFA delete not enabled |
| `aws_instance.app` | CKV_AWS_8 | IMDSv2 not enforced |
| `aws_security_group.app` | CKV_AWS_25 | SSH open to 0.0.0.0/0 |
| K8s Deployment | CKV_K8S_28 | Container runs as root |
| K8s Deployment | CKV_K8S_30 | No resource limits set |

## Running Checkov locally

```bash
pip install checkov
checkov -d terraform/
checkov -d kubernetes/ --framework kubernetes
```
