# AWS APP Ingress Terraform script

## Initialise the main Terraform project and apply the changes to the AWS account
# terraform init -backend-config="profile=$PROFILE_NAME" -backend-config="bucket=af-south-1-$ENV-tfstate" -backend-config="dynamodb_table=af-south-1-$ENV-tfstate-locks"

*NB* the only way to pass variables (like aws_profile to use) to the init command is through the use of the `-backend-config` option.
 
Can also pass all relevant backend config in a single properties file under the /backends folder.

`$# terraform init -backend-config=./backends/${ENV}.properties`

Each environment has a corresponding Terraform variables file, check the values in the file corresponding with the environment you wish to deploy to:

In the same directory:

`$#  terraform apply -var-file=./vars/$ENV.tfvars`

## Naming Standard:
co-mz-ubuntu-[aws-resource]-[zone]-[?env]

> ### Manages (Create/Update/Destroys) the following resources:
>
> - S3 UI bucket called app.${var_domain}.
> - CloudFront distribution that fronts the S3 bucket with Origin Access Identity.