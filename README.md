# Cloud Deployment and Hosting

Application is running on
http://hello-world-ecs-dev-2041763857.eu-west-2.elb.amazonaws.com/

## Application

The applicaiton consists of a simple Hello World website, with an HTML page. They are inside the `app/` directory.

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

