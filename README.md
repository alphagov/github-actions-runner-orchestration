# github-actions-runner-orchestration ![Experimental](https://img.shields.io/badge/Status-Experimental-orange.svg)
GARO - serverless (AWS Lambda) GitHub Actions self-hosted EC2 runner orchestration tool

## What is it?
This is an experimental API for running ephemeral GitHub Action runners in EC2 instances.

## How does it work?
1. starts with a POST to the `/start` endpoint
2. API validates the request
3. API tries to assume the role in the specified account with an [external ID](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_create_for-user_externalid.html)
4. API starts either a `spot` or `ondemand` instance
5. Instance configures itself using a [PAT](https://docs.github.com/en/github/authenticating-to-github/creating-a-personal-access-token) retrieved from SSM Parameter Store
6. returns status

## Requirements
- 2x IAM roles
  - role for assuming from API
  - role for instances to use
- PAT in SSM
- Params in GitHub secrets / env vars

## How to use?

The [client](client/) will start up an instance and wait for it to be active:

```yml
- name: Get Runner
  uses: alphagov/github-actions-runner-orchestration/client@main
  id: garoclient
  with:
    ACTION: 'start'
    GITHUB_TOKEN: '${{ secrets.GITHUB_TOKEN }}'
    RUNNER_TYPE: 'spot'
    REPO: '${{ github.repository }}'
    GITHUB_COMMIT: '${{ github.sha }}'
    RUNNER_SUBNET: '${{ secrets.RUNNER_SUBNET }}'
    RUNNER_SG: '${{ secrets.RUNNER_SG }}'
    RUNNER_ACID: '${{ secrets.RUNNER_ACID }}'
    RUNNER_EXID: '${{ secrets.RUNNER_EXID }}'
    GARO_URL: '${{ secrets.GARO_URL }}'

- name: Output runner details
  run: |
    echo "Name ${{ steps.garoclient.outputs.name }}"
    echo "State ${{ steps.garoclient.outputs.runnerstate }}"
```
