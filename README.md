# tofu-wagtail
This is my attempt at using OpenTofu to manage Heroku, AWS and Cloudflare for web hosting

## Useage
This should work with either terraform or OpenTofu
The state is stored in an S3 bucket, along with `imports.tf` and `terraform.tfvars` files.
To do this a working AWS CLI and the following env vars are required:

* TERAFORM_BUCKET - The bucket name
* TERAFORM_BUCKET_REGION - The bucket region
* TERAFORM_BUCKET_PATH - Path/prefix to use in the bucket

Then just run `make init` to do it's thing or `make help` to see what else it can do
