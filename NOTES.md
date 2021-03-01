# Notes

I've collected here what was in my mind and the issues I found on the way.

In summary, I started off a non-working, non-so-complete example of ECS from the terraform registry! https://github.com/terraform-aws-modules/terraform-aws-ecs/tree/master/examples/complete-ecs

What I thought would have been a shortcut to have the ECS service up and running got me into some troubles.

## Initial thoughts

When reading the challenge, I started considering where to run the website.

Static HTML and an image would just require S3, with potentially CloudFront. Scalability would come for free, plus other advantages with security and simplicity.

That said, the company would likely want to build a dynamic website, at which point possible solutions are:
* beanstalk
* EKS
* ECS
* lambda
* docker on lambda

If it would fit the purpose of the new site, lambda would be my first choice. Less infrastructure maintenance, scalability for free. To be honest I don't know how good docker on lambda is, but it would be evaluated.

Second choice would be EKS, as kubernetes has a lot of traction and managed kubernetes wins.

For the purpose of this exercise, I will use the good old ECS as I have most familiarity with it.

## Application

I created a simple Hello World website, with an HTML page and image as requested. They are inside the `app/` directory.

The HTML can be tested quickly by opening it in the browser.

Next is to run in docker.

See [README](README.md#Docker - Local development).

## Setting up the infrastructure

First I will create the ECS cluster and VPCs in my personal AWS account.
I will use https://github.com/terraform-aws-modules/terraform-aws-ecs/tree/master/examples/complete-ecs as a starting point.

### Setup terraform

Download from https://www.terraform.io/

On Mac you can do `brew install terraform`.

```
$ cd terraform/
$ terraform init
```

Changes to `examples/complete-ecs`:
* they are referring to modules in `../..` - use the terraform registry instead
* created a directory `terraform/app-hello-world` to hold the task configuration; copied and adapted from https://github.com/terraform-aws-modules/terraform-aws-ecs/tree/v2.8.0/examples/complete-ecs/service-hello-world

I had troubles running terraform on my old MacBook Late 2008. I fought a while with it, with errors hinting at a corrupted module. In the end I spun an EC2 instance and it worked at the first go!

A long debug session...

When setting the ASG to have 1 instance, a new instance would start but it wouldn't join the ECS cluster. The logs of the machine weren't shipped to CloudWatch, and the machine was private with no direct access. As I wasn't sure the ECS configuration was written correctly by user data, I opted for launching manually an EC2 instance in the public subnet, creating a security group that was only allowing port 22 traffic and from my home IP address. I also had to change the SG for the private EC2 instances to allow traffic from the public subnet, and update the ASG to use an SSH key. When jumping on the server, error in /var/log/ecs/ecs-agent.log was:

```
level=error time=2021-02-28T00:28:17Z msg="Unable to register as a container instance with ECS: RequestError: send request failed\ncaused by: Post \"https://ecs.eu-west-2.amazonaws.com/\": net/http: request canceled while waiting for connection (Client.Timeout exceeded while awaiting headers)" module=client.go
```

This pointed at two solutions:
* NAT gateway not setup for the private subnets
* VPC endpoints not setup

Given the example had the following, I changed it to `true`.

```
enable_nat_gateway = false # false is just faster
```

And TA-DA, the EC2 instance joined the cluster!

Next, the service wouldn't start. Error visible in the ECS console:

```
Status reason	CannotStartContainerError: Error response from daemon: failed to initialize logging driver: failed to create Cloudwatch log stream: ResourceNotFoundException: The specified log group does not exist.
```

It turns out it was my fault in using region `eu-west-1` for CloudWatch in the task configuration.

The task now starts, with the logs showing:

```
2021-02-28 11:05:42Hello from Docker!
2021-02-28 11:05:42This message shows that your installation appears to be working correctly.
2021-02-28 11:05:42To generate this message, Docker took the following steps:
2021-02-28 11:05:421. The Docker client contacted the Docker daemon.
2021-02-28 11:05:422. The Docker daemon pulled the "hello-world" image from the Docker Hub.
2021-02-28 11:05:42(amd64)
2021-02-28 11:05:423. The Docker daemon created a new container from that image which runs the
2021-02-28 11:05:42executable that produces the output you are currently reading.
2021-02-28 11:05:424. The Docker daemon streamed that output to the Docker client, which sent it
2021-02-28 11:05:42to your terminal.
2021-02-28 11:05:42To try something more ambitious, you can run an Ubuntu container with:
2021-02-28 11:05:42$ docker run -it ubuntu bash
2021-02-28 11:05:42Share images, automate workflows, and more with a free Docker ID:
2021-02-28 11:05:42https://hub.docker.com/
2021-02-28 11:05:42For more examples and ideas, visit:
2021-02-28 11:05:42https://docs.docker.com/get-started/
```

Next: build an image and push to ECR. As a start:
* create an ECR repository in terraform
* build and push manually
* TODO: automate build and push

#### Build and push image (manually)

```
# ECR login
eval $(aws ecr get-login --region eu-west-2 --no-include-email)

# initialize
export VERSION=dev-`date "+%Y%m%d-%H%M"`
export ECR_IMAGE=454648136210.dkr.ecr.eu-west-2.amazonaws.com/hello-world:$VERSION

# build image
docker build -t hello-world:$VERSION -f docker/prd/Dockerfile .

# tag and push, versioned tag
docker tag hello-world:$VERSION $ECR_IMAGE
docker push $ECR_IMAGE

echo 'ECR image: ' $ECR_IMAGE
```

Updated the task definition to use `454648136210.dkr.ecr.eu-west-2.amazonaws.com/hello-world:dev-20210228-2123`.

Created ALB, make the ECS service using its target group. Not healthy atm!

After some refactoring of terraform and the markdown documents:
* hostPort on the ECS task definition wasn't right
* made instance type smaller

Still no luck with the target group health check.