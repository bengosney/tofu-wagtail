.PHONY: help check init clean download
.DEFAULT_GOAL: help
.PRECIOUS: imports.tf terraform.tfvars

CMD=$(shell which tofu || which terraform)
ECHO=$(shell which figlet || which echo)

init: check .terraform ## Fetch files from S3 and init

download: clean imports.tf terraform.tfvars ## Refetch the imports and vars

help: ## Display this help
	@$(ECHO) Infrastructure
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

.terraform: imports.tf terraform.tfvars
	$(CMD) init \
		-backend-config="key=${TERAFORM_BUCKET_PATH}/state.tfstate" \
		-backend-config="bucket=${TERAFORM_BUCKET}" \
		-backend-config="region=${TERAFORM_BUCKET_REGION}"
	@touch $@

imports.tf:
	aws s3api get-object --bucket "${TERAFORM_BUCKET}" --key "${TERAFORM_BUCKET_PATH}/$@" "$@"

terraform.tfvars:
	aws s3api get-object --bucket "${TERAFORM_BUCKET}" --key "${TERAFORM_BUCKET_PATH}/$@" "$@"

check: ## Check the env vars are set
ifndef TERAFORM_BUCKET
	$(error "TERAFORM_BUCKET is required!")
endif
ifndef TERAFORM_BUCKET_REGION
	$(error "TERAFORM_BUCKET_REGION is required!")
endif
ifndef TERAFORM_BUCKET_PATH
	$(error "TERAFORM_BUCKET_PATH is required!")
endif

clean: ## Remove fetched files
	@rm -f imports.tf terraform.tfvars
