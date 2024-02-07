# Example of Terraform project for lambda-lb-target-group-dns

It creates Target Group then sets an Eventbridge schedule that triggers
Lambda for updating the targets.

## Usage

Create `terraform.tfvars` based on example file.

Run `goreleaser release --snapshot` from the top directory to get ZIP files then:

```sh
terraform init
terraform apply
```
