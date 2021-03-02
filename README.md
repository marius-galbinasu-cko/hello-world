# Cloud Deployment and Hosting

Application is running on
http://hello-world-ecs-dev-2041763857.eu-west-2.elb.amazonaws.com/

## Application

The applicaiton consists of a simple Hello World website, with an HTML page. They are inside the [app/](app/) directory.

The HTML can be tested quickly by opening it in the browser.

### Docker - Local development

#### Dev version

In dev mode, the `app/` directory is not built inside the docker image but mounted directly in the container.
Any change to the files would be available immediately on the running instance.

Build and run with:

```
docker-compose -f dev.yml up --build
```

#### Production version

In production mode, the `app/` directory is built in the docker image.
You would try this mode locally just before pushing the changes and trigger a pipeline.

Build and run with:

```
docker-compose -f prd.yml up --build
```

## Infrastructure

### Prerequisite

Download terraform from https://www.terraform.io/

On Mac you can do `brew install terraform`.

### Deploy the infrastructure and application

They are together for now.

```
cd terraform/
terraform init
terraform apply
```

### Build and push image (manually)

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

## Scaling

Scaling would be done automatically by setting scaling policies on the application and the servers. For the purpose of a demo, before auto-scaling can be tested thoroughly, manual scaling instructions are provided.

### Manual scaling

Manual scaling can be achieved:
* on the application, by increasing the ECS's service `request_count` in [terraform/app-hello-world/main.tf](terraform/app-hello-world/main.tf):

```
resource "aws_ecs_service" "hello_world" {
   ...

  desired_count = 1
```

* on the servers, by increasing the number of servers, in particular the `desired_capacity`, in [terraform/main.tf](terraform/main.tf):

```
module "asg" {
  source  = "terraform-aws-modules/autoscaling/aws"

  ...

  min_size                  = 0
  max_size                  = 2
  desired_capacity          = 1
```

### Auto-scaling

Auto-scaling can be achieved by:
* making the service itself auto-scale (application scaling)
* making the EC2 instances under the hood scaling (server scaling)

The criteria that should determine the application scaling up are normally the number of requests, response time, CPU, but they are application dependent.

Server scaling is driven by the CPU and memory usage across all the servers in the ECS cluster.