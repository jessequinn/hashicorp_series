.PHONY: validate
validate:
	@packer validate -var-file=variables.json template.json

.PHONY: build
build:
	@packer build -var-file=variables.json template.json
