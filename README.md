# github-actions-runner-orchestration (GARO)
![Experimental](https://img.shields.io/badge/Status-Experimental-orange.svg) [![Test and deploy to staging and production](https://github.com/alphagov/github-actions-runner-orchestration/actions/workflows/deploy.yml/badge.svg?branch=main)](https://github.com/alphagov/github-actions-runner-orchestration/actions/workflows/deploy.yml)

## What is it?
GARO is an experimental serverless (AWS Lambda) API for running GitHub Action
runners in self-hosted, ephemeral EC2 instances.

## How to use?

The [garo client] will start up an instance and wait for it to be active.  
See the [client README](client/README.md) for details and an example.

There are also the [workflows here] which use this tool.

## Requirements for [client] (or direct API use)
- subnets with external internet access (recommend via a NAT gateway)
- security group for the runner instances
- 2x IAM roles (see [terraform_module](terraform_module/) for these)
    1. role for assuming from API (with random [external ID] added as a condition)
    2. role for instances to use (allow assume from the first role)
- PAT in SSM (`/github/runner/pat`) with repo write access (for adding runners to a repo)
- Params in GitHub secrets / environment variables (recommend using [GitHub Environments](https://docs.github.com/en/actions/reference/environments) with branch protections)

## Development
See the [development documentation].

[development documentation]: docs/development.md
[workflows here]: .github/workflows/
[external ID]: https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_create_for-user_externalid.html
[garo client]: client/
