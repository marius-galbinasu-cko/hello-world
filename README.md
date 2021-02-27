# Cloud Deployment and Hosting

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

### Docker - Local development

#### Dev version

In dev mode, the `app/` directory is not built inside the docker image but mounted directly in the container.
Any change to the files would be available immediately on the running instance.

Build and run with:

```
$ docker-compose -f dev.yml up --build
```

#### Production version

In production mode, the `app/` directory is built in the docker image.
You would try this mode locally just before pushing the changes and trigger a pipeline.

Build and run with:

```
$ docker-compose -f prd.yml up --build
```

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

I had troubles running terraform on my old MacBook Late 2008. I fought a while with it, until I spun an EC2 instance and it worked at the first go!

