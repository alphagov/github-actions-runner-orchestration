# github-actions-runner-orchestration
![Experimental](https://img.shields.io/badge/Status-Experimental-orange.svg) [![Test and deploy to staging and production](https://github.com/alphagov/github-actions-runner-orchestration/actions/workflows/deploy.yml/badge.svg?branch=main)](https://github.com/alphagov/github-actions-runner-orchestration/actions/workflows/deploy.yml)

GARO - serverless (AWS Lambda) GitHub Actions self-hosted EC2 runner orchestration tool

## What is it?
This is an experimental API for running ephemeral GitHub Action runners in EC2 instances.

## How does the client work?
1. starts with a POST to the `/start` endpoint
2. API validates the request
3. API tries to assume the role in the specified account with an [external ID]
4. API checks if a matching instance (by labels and instance type) already exists
   1. if yes, returns the unique ID
   1. if not:
      1. API starts either a `spot` or `ondemand` instance
      1. instance configures itself using a [PAT](https://docs.github.com/en/github/authenticating-to-github/creating-a-personal-access-token) retrieved from SSM Parameter Store
      1. waits for instance to start
5. returns started status

## Requirements for [client] (or direct API use)
- subnets with external internet access (recommend via a NAT gateway)
- security group for the runner instances
- 2x IAM roles (see [terraform_module](terraform_module/) for these)
    1. role for assuming from API (with random [external ID] added as a condition)
    2. role for instances to use (allow assume from the first role)
- PAT in SSM (`/github/runner/pat`) with repo write access (for adding runners to a repo)
- Params in GitHub secrets / environment variables (recommend using [GitHub Environments](https://docs.github.com/en/actions/reference/environments) with branch protections) 

## How to use?

The [client] will start up an instance and wait for it to be active. See the [client README](client/README.md) for details and an example.


[external ID]: https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_create_for-user_externalid.html
[client]: client/
