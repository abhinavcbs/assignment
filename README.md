# assignment
terraform code for completing the assignment
The repository contains the code for creating the below mentioned aws components using terraform:

-> VPC
-> 3 subnets 2 public 1 private
-> Internet gateway
-> Main route table and route table association
-> Other route table and route table association
-> NAT gateway and EIP for NAT gateway
-> 2 security groups (1 for Public Load balancer & bastion server & 1 for Private EC2)
-> Security group rules
-> AWS acm certificate (for uploading self signed certificate)
-> Target group
-> Load balancer
-> Listener
-> Auto scaling group & attachment & autoscaling policy 
-> Launch template 
-> Route53 private hosted zone & record
-> IAM role, policy & attachment
-> Cloudwatch alarm
-> Bastion server 

The infrastructure is created keeping the below considerations in mind:

-> Public subnets are created for ELB & private subnets are created for EC2 instances as they do not need access from/to the internet.
-> A self-signed certificate for test.example.com is created and will be used with load balancer, this dns resolves internally within VPC network with route 53
private hosted zone.
-> The instance in the ASG contains both a root volume to store the application/services and a secondary volume meant to store any log data bound
from /var/log. The same is mounted using a function in userdata. 
-> All configuration is defined in the launch configuration and/or the user
data script and no manual intervention is required.
-> All data is encrypted at rest, EBS voluems in the launch template are encrypted.
-> For web servers, passsword based access is configured so that they can be managed without logging in with the ssh keys. Web servers can be accessed through the bastion server.
The below command can be used from any bastion server launched in the same subnet, sshpass utility is already installed via bastion_userdata:
"sshpass -p 'password' ssh  -o StrictHostKeyChecking=no application@10.X.X.XXX -p 22"
-> The application can be accessed using the curl (curl --insecure https://test.example.com) command from the bastion or using curl --insecure <load_balancer_dns> from the internet.
-> A ssh key needs to be provided for bastion (not included in code) 
-> Autoscaling group is configured to automatically add and remove nodes based on CPU
load.
-> CloudWatch alarm is created to indicate when the application is experiencing any issues.

