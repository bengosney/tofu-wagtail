.PHONY: help _check
.DEFAULT_GOAL: .terraform

help: ## Display this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

.terraform: _check imports.tf terraform.tfvars
	tofu init \
		-backend-config="key=${TERAFORM_BUCKET_PATH}/state.tfstate" \
		-backend-config="bucket=${TERAFORM_BUCKET}" \
		-backend-config="region=${TERAFORM_BUCKET_REGION}"

imports.tf: _check
	aws s3api get-object --bucket "${TERAFORM_BUCKET}" --key "${TERAFORM_BUCKET_PATH}/$@" "$@"

terraform.tfvars: _check
	aws s3api get-object --bucket "${TERAFORM_BUCKET}" --key "${TERAFORM_BUCKET_PATH}/$@" "$@"

_check:
ifndef TERAFORM_BUCKET
	$(error "TERAFORM_BUCKET is required!")
endif
ifndef TERAFORM_BUCKET_REGION
	$(error "TERAFORM_BUCKET_REGION is required!")
endif
ifndef TERAFORM_BUCKET_PATH
	$(error "TERAFORM_BUCKET_PATH is required!")
endif
