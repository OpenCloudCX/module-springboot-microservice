# OpenCloudCX Springboot Microservice Primer Module

Using this module within OpenCloudCX will create Jenkins (C) and Spinnaker (CD) resources. This module should be used in the bolt-on project. Including in the bootstrap project will produce a provider race condition and will not execute.

# Setup

Add the following module definition to the bootstrap project

```
module "springboot-microservice" {
  <source block>

  github_hook_pw  = "<github hook password>"

  providers = {
    kubernetes = kubernetes,
    jenkins    = jenkins,
    spinnaker  = spinnaker,
  }
}
```

# Source block

The source block will be in either of these formats

## Local filesystem

```
source = "<path to module>"
```

## Git repository

```
source = "git::ssh://git@github.com/<account or organization>/<repository>?ref=<branch>"
```

Note: If pulling from `main` branch, `?ref=<branch>` is not necessary.

## Terraform module

```
source  = "<url to terraform module>"
version = "<version>"
```

Verion formatting of the terraform source block [explained](https://www.terraform.io/docs/language/expressions/version-constraints.html)

# Providers

Provider references should be supplied through the `providers` configuration of the module. This information is provided from the OpenCloudCX bootstrap project as outlined in the variables section above

```
provider "kubernetes" {
  host                   = var.eks_host
  token                  = var.eks_token
  cluster_ca_certificate = var.cluster_ca_certificate
}

provider "jenkins" {
  server_url = "http://${var.jenkins_host}.${var.dns_zone}"
  username   = "admin"
  password   = var.jenkins_pw
}
```

Note: When multiple environments or cloud-providers are in use, the named module reference will need to be changed per environment.

## Module example with Git repository reference

This example also adds a `kubernetes_namespace` definition to create the namespace if one does not already exist.

```terraform
provider "kubernetes" {
  host                   = var.eks_host
  token                  = var.eks_token
  cluster_ca_certificate = var.cluster_ca_certificate
}

provider "jenkins" {
  server_url = "http://${var.jenkins_host}.${var.dns_zone}"
  username   = "admin"
  password   = var.jenkins_pw
}

provider "spinnaker" {
  server             = "http://${var.spinnaker_host}.${var.dns_zone}"
  ignore_cert_errors = true
}

module "springboot-microservice" {
  source = "git::ssh://git@github.com/OpenCloudCX/module-springboot-microservice?ref=develop"

  github_hook_pw = var.github_hook_pw

  providers = {
    kubernetes = kubernetes,
    jenkins    = jenkins,
    spinnaker  = spinnaker,
  }
}

```
