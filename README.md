# Easy AWS Privacy VPN (EAPV)

Easily setup a VPN via the AWS cloud for the privacy of your online traffic.  Comparable to commercial VPN providers like [NordVPN®](https://nordvpn.com), and the ["free"](./docs/Comparision.md#free-aws-ec2-openvpn-solution) AWS EC2 OpenVPN solution as described [here (YouTube)](https://www.youtube.com/watch?v=R82Peq5T9jQ) and [here (article)](https://aws.plainenglish.io/setting-up-a-free-vpn-server-in-aws-fd3e25f4f7ac).  See [here](./docs/Comparision.md) for a more detailed comparison of the solutions.

This solution costs 15.5¢ ($USD) per hour while you're using it.  Exception: Traffic over 100GB/month will also incur [data transfer costs](./docs/Comparision.md#aws-data-transfer).

And **if you remember to stop it properly when done** then it costs nothing while you're not using it.

This solution is best suited for one-time or occassional use.  The downsides are that:
- it takes 6+ minutes to start the AWS backend before you can open a VPN session; and
- you need to remember to stop the AWS backend when you're done so that it doesn't acrue costs while you're not using it.

## Steps

### Optional

Visit [https://www.whatismyip.com](https://www.whatismyip.com).  Any website you visit can see your IP address, internet service provider (ISP), and your general location.

### One-time Steps

#### 1. Install the AWS CLI software

Follow [these instructions](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html#getting-started-install-instructions).  Don't set up or configure it yet, just install it.

You'll need this for starting and stopping the AWS backend when you use the VPN.

#### 2. Install the AWS VPN Client software

Download the software [here](https://aws.amazon.com/vpn/client-vpn-download/), then install it.

This will run the VPN connection from your computer to the AWS backend.

#### 3. Get an AWS account

Follow [these steps](https://aws.amazon.com/free).  A credit card is required.

Then sign in to the [AWS Console](https://us-east-1.console.aws.amazon.com/console).  

If you already have an AWS account you can probably use it, but this solution relies on a default-state VPC.  If you're using the default VPC in the target Region consider instead creating an [AWS Organization account](https://docs.aws.amazon.com/organizations/).

#### 4. Open a CloudShell terminal

From the AWS Console, click on "CloudShell" in the bottom left corner.

#### 5. Set up the AWS account

In the CloudShell terminal run:
```bash
git clone https://github.com/paulmossman/easy-aws-privacy-vpn
cd easy-aws-privacy-vpn
chmod +x ./bin/*
./bin/account-setup.sh
```

#### 6. Create an AWS access key for the IAM user

From the AWS Console, navigate to the IAM (Identity and Access Management) service → Users → easy-aws-privacy-vpn → Security credentials.   ([shortcut](https://console.aws.amazon.com/iam/home#/users/details/easy-aws-privacy-vpn?section=security_credentials))  Scroll down to "Access keys" and click "Create access key":
- Use case: Command Line Interface (CLI)
    - Note the recommendation "to improve your security."
    - Select "I understand the above recommendation and want to proceed to create an access key."
    - (See [EAPV Security](./docs/Security.md) for more details.)
- "Next" button
- (Optional) Description tag value: Today's date
- "Create access key" button

You'll need the "Access key" and "Secret access key" values in the next step.

#### 7. Configure the AWS CLI software

Open a command-line session on your **local computer**.  i.e. ```cmd``` or PowerShell on Windows, "Terminal" on Mac or Linux.

Run:
```bash
aws configure --profile easy-aws-privacy-vpn
```

When prompted for "AWS Access Key ID" enter the "Access key" from the previous step.

When prompted for "AWS Secret Access Key" enter the "Secret access key" from the previous step.

Don't provide values for the other two prompts.  i.e. Just press Enter.

### Per-Region Steps

Decide which [AWS Region](https://aws.amazon.com/about-aws/global-infrastructure/regions_az/) you want to use.  **This is where your online traffic will appear to come from.**  (You can repeat the Per-Region steps later if you want to use different Regions.)

#### 8. Get the Region Code

See [this table](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-regions-availability-zones.html#concepts-available-regions).  For example ```us-east-1``` for N. Virginia.

If your Region's **Opt-in status** is "Required" then you need to enable it first.  See "AWS Regions" [here](https://us-east-1.console.aws.amazon.com/billing/home#/account).

You'll notice in your AWS Console (at the top, near the right) that a Region is selected, and  you can change Regions.  For these instructions it doesn't matter what Region is selected in the AWS Console.

#### 9. Set up the Region

In the CloudShell terminal run:
```bash
./bin/region-setup.sh <Region Code>
```
Substitute "\<Region Code\>" for the Region Code you selected in the previous step.

#### 10. Download the AWS backend script and VPN configuration file

The command in the previous step will list the names of the two files to download.  From CloudShell, for each of the two files,  select Actions → Download file → Enter file file name → click "Download".  The files will be downloaded to your browser's "Downloads" directory.

#### 11. Create the AWS VPN Client profile

Start the AWS VPN Client software, then:
- File → Manage profiles
- click "Add Profile"
    - Display Name: "EAPV \<Region\>", where \<Region\> is the Region Code
    - VPN Configuration File: The .ovpn file downloaded in the previous step
    - click "Add Profile"
- click "Done"

### VPN Session Activation Steps

Follow these steps every time you want to use the VPN.

#### 12. Start the AWS backend

Open a command-line session on your **local computer**.  i.e. ```cmd``` or PowerShell on Windows, "Terminal" on Mac or Linux.  Change to your browser's "Downloads" directory, and run:

Mac or Linux:
```bash
./eapv-<Region Code>-aws-backend.sh start
```
Windows:
```
eapv-<Region Code>-aws-backend.bat start
```
(Substitute "\<Region Code\>" for the Region Code.)

This will take 6+ minutes to complete, at which point the AWS backend will start to cost 10.5¢/hour.

#### 13. Start the AWS VPN Client session

From the AWS VPN Client software ensure the correct "Profile" is selected then click "Connect".

Upon connecting the client session will cost 5¢/hour, in addition to the AWS backend cost above.

#### 14. Check your IP (optional)

Visit [https://www.whatismyip.com](https://www.whatismyip.com) again.  Your ISP should now be be "Amazon" or "AWS", and your location should match the Region that you're using.

### VPN Session Teardown Steps

Follow these steps every time you're done using the VPN.

#### Stop the AWS backend

On your **local computer** run:

Mac or Linux:
```bash
./eapv-<Region Code>-aws-backend.sh stop
```
Windows:
```
eapv-<Region Code>-aws-backend.bat stop
```
(Substitute "\<Region Code\>" for the Region Code.)

This will also disconnect the AWS VPN Client session, but it will automatiacally try to re-establish the connection.  Simply click "Disconnect" and exit the application.

If you only end the AWS VPN Client session then AWS will continue to charge you 10.5¢/hour while the backend is running.  So run the above "stop" script before you quit the AWS VPN Client or turn your computer off.

#### Check the status of the AWS backend (optional)

To check the status of the AWS backend run:

Mac or Linux:
```bash
./eapv-<Region Code>-aws-backend.sh status
```
Windows:
```
eapv-<Region Code>-aws-backend.bat status
```
(Substitute "\<Region Code\>" for the Region Code.)

### Per-Region Teardown (optional)

To teardown the configuration of a Region, in the AWS CloudShell run:
```bash
./bin/region-teardown.sh  <Region Code>
```

### Per-Account Teardown (optional)

If you no longer want to use the Easy AWS Privacy VPN solution then you can remove it comeltely from your AWS account.  First teardown all Regions you've set up.  Then in the AWS CloudShell **in the Region where you first ran** ```region-setup.sh```, run:
```bash
./bin/account-teardown.sh
```

# Limitations

## SSL Certificate Expiry

The Region configuration uses an SSL certificate that expires 825 days from creation.  When it expires simply teardown the Region configuration, then set it up again from scratch.
