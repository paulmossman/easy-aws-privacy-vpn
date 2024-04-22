# EAPV Roadmap

## Include a new VPC in the per-Region setup

User Story: As the person installing and configuring this solution I want to be able to successfully deploy it into a new VPC so that I don't have to install it into a default-state VPC. 
Acceptance Criteria:
1. A new VPC is created.
2. Multiple instances of the solution can be deployed into a single Region in a single account.  (Horizontal Scale.)
3. region-teardown.sh uses the vpc.json stored for the Region in S3 if it needs to behave differently to be backward-compatible with older installs that used the default VPC.  (It should of course not delete the default VPC.  But that should be taken care of by only deleting a created VPC via deleting the per-Region CloudFormation stack.)

## Import ACM Certificates via CloudFormation

There doesn't seem to be a way to import an ACM Certificate using CloudFormation...
See: https://docs.aws.amazon.com/acm/latest/userguide/import-certificate-api-cli.html
