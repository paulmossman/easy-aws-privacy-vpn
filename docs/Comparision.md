# EAPV compared to other solutions

| Factor            | Easy AWS Privacy VPN | Commercial VPN | AWS EC2 OpenVPN |
| :---------------- | :------: | :------: | :------: |
| Easy to setup     | 🟡 | 🟢 | 🔴 |
| Performance       | 🟢 | 🟢 | 🔴 |
| Quick session start | 🔴 | 🟢 | 🟢 |
| Simple session stop (no extra $ for forgetting to stop an AWS backend) | 🔴 | 🟢 | 🟢 |
| Unlimited use for flat rate | 🔴 | 🟢 | 🟡 |
| $0 when not in use | 🟢 | 🔴 | 🔴 |
| Cheap for one-time or occassional use | 🟢 | 🔴 | 🟢/🔴 |
| Resilient (fewest [SPOF](https://en.wikipedia.org/wiki/Single_point_of_failure)) | 🟡 | 🟢 | 🔴 |

# Cost

## Easy AWS Privacy VPN (EAPV)

### AWS Data Transfer

[AWS Free Tier](https://aws.amazon.com/free/) gives you the first 100GB of data transfer per month free, even after your first 12 months.

Traffic over 100GB/month is charged as described [here](https://aws.amazon.com/ec2/pricing/on-demand/#Data_Transfer).

### Other

Using the VPN incurs the following costs:
- $0.10/hour for each Subnet associated to a Client VPN endpoint; plus
- $0.005/hour for each Public IP address in use (required for the above); plus
- $0.05/hour for each VPN client connected.

Risk: If you only stop the VPN client connection, the backend in AWS continues to run at a cost of $0.105/hour.  You need to remember to stop the AWS backend when you're done using the VPN.

## Commercial VPN

Various prices, but generally flat rate for unlimited use and discounted for 1+ year terms.

## "free" AWS EC2 OpenVPN solution

It isn't always free...

### AWS Data Transfer

This solution has the same AWS Data Transfer costs as described above.  i.e. Over 100GB/month of data transfer isn't free. 

### EC2 instance with Public IP address

After you've had your AWS account for 12 months, the AWS OpenVPN solution will cost:
- $0.0116/hour for the t2.micro EC2 instance: $8.70/month
- $0.005/hour for the Public IP address: $3.75/month
- $0.08/GB-month for (default) 8GB EBS: $0.64/month

See the [AWS Free Tier FAQs](https://aws.amazon.com/free/free-tier-faqs/) for more details.

The monthly total will be $13.09/month.  That's roughly the same cost as using Easy AWS Privacy VPN for 85 hours per month.
