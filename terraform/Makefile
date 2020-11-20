.PHONY: init
init:
	@terraform init

.PHONY: validate
validate:
	@terraform validate

.PHONY: build
build:
	@terraform plan -var-file="definitions.tfvars"
	@terraform apply -var-file="definitions.tfvars"

.PHONY: destroy
destroy:
	@terraform destroy -var-file="definitions.tfvars"
