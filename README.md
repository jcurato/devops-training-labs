# DevOps + AI — training labs

Hands-on Terraform labs for the [J Curato Solutions](https://jcurato.com) DevOps + AI cohort.
Each week of the course has its own directory here — real infrastructure, not a slide deck.

## Structure

```
devops-training-labs/
├── week-01-cluster-foundation/   EKS cluster: VPC, node groups, why the defaults fail
├── modules/                      Shared Terraform modules, added as later weeks need them
└── README.md
```

More weeks get added as their course material is written — see the
[cohort syllabus](https://jcurato.com) for the full 8-week roadmap.

## Prerequisites

- An AWS account (**your own** — labs are not run against a shared account)
- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.16
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) v2, configured with your own credentials:
  ```bash
  aws configure --profile <your-profile>
  ```

## Cost — read this before you run anything

**EKS, NAT Gateways, and load balancers are never free**, on any AWS account, on any
plan — see the cost breakdown on [jcurato.com](https://jcurato.com) if you haven't already.
A cluster left running racks up real charges whether you're using it or not.

**Tear down every lab when you're done with it:**

```bash
cd week-01-cluster-foundation
terraform destroy
```

Set a [Budget alert](https://console.aws.amazon.com/billing/home#/budgets) in your own
account before you run `terraform apply` for the first time. Nobody here is watching your bill for you.

## Running a lab

```bash
cd week-01-cluster-foundation
terraform init
terraform plan      # read this output before you apply anything
terraform apply
```
