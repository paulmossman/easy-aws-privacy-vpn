# EAPV Security

## AWS CLI configured on the local computer

You'll notice when creating the AWS access key for the IAM User that alternatives are recommended.  Easy AWS Privacy VPN does use "AWS CloudShell" alternative for most of its setup.

These credentials are configured on your local computer so that you don't need to login to the AWS Console each time you start/stop the AWS backend.  As per the [security principle of least privilege](https://en.wikipedia.org/wiki/Principle_of_least_privilege), they have very limited permissions:
- Only on Client VPN endpoint(s) with the Tag Application=easy-aws-privacy-vpn:
  - Describe it
  - Describe, Create, and Delete its Target network (subnet) associations
  - Describe, Create, and Delete its Route table entries
- On any Subnet:
  - Create and Delete Target network associations for it to a Client VPN endpoint
  - Create and Delete entries for it in a Client VPN endpoint's Route table
- Only on CloudFormation stack(s) named "eapv-region-active":
  - Describe it
  - Create it
  - Delete it
- Only on an S3 Bucket named easy-aws-privacy-vpn-\<AWS Account ID\>:
  - List it
  - Get objects in it

Vulnerability: These credentials could be used to create a Target network association to every subnet in the VPC that the Client VPN endpoint is in, at a cost of $0.105/hour/subnet.  Default VPCs typically only have three or fewer subnets, and these credentials do not have permission to create more subnets.
