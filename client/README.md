# GARO Action

This action spins up and ephemerial runner in your own AWS environment.

## Inputs

#### -- Required --

### `GITHUB_TOKEN`

**Required** The token from the workflow run.

For most cases, set to: `'${{ secrets.GITHUB_TOKEN }}'`

### `REPO`

**Required** The repo name (including organisation), for example `alphagov/github-actions-runner-orchestration`.

For most cases, set to `'${{ github.repository }}'`

### `GITHUB_COMMIT`

**Required** The commit SHA from the workflow run.

For most cases, set to: `'${{ github.sha }}'`

### `RUNNER_ACID`

**Required** The AWS account ID where to assume the `GitHubRunnerAssumeRole` role.

### `RUNNER_EXID`

**Required** The AWS external ID that's set as a condition in the `GitHubRunnerAssumeRole` role.

See here [for more information about external IDs](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_create_for-user_externalid.html).

#### -- Optionals --

### `RUNNER_SUBNET`

_optional_ The AWS subnet to start the runner in - must be set with `ACTION: 'start'`.

### `RUNNER_SG`

_optional_ The AWS security group to assign to the runner - must be set with `ACTION: 'start'`.

### `RUNNER_TYPE`

_optional_ The type of instance for runner `spot | ondemand`.

### `RUNNER_LABEL`

_optional_ CSV of additional labels for the runner, for example `firstjob,123`

Can be useful for specifying particular classes of runner.

### `RUNNER_NAME`

_optional_ An existing runners name - must only be set with `ACTION: 'state'`.

### `RUNNER_TIMEOUT`

_optional_ How long the runner idles for in seconds.

Default: `3600` (1 hour)

### `RUNNER_REGION`

_optional_ The AWS region name, for example `eu-west-2`.

Default: `eu-west-2`

### `GARO_URL`

_optional_ The API url.

Default: https://prod.co-cdio-garo.digital

### `ACTION`

_optional_ `start | state`.

Default: `start`

### `WAIT_FOR_START`

_optional_ Whether to wait for the runner to start `yes | no`.

Default: `yes`


## Outputs

### `name`

The full runner name.

### `runnerstate`

The runner's state.

### `uniqueid`

The runner's unique ID that's randomly generated when created.

## Example usage

``` yml
steps:
  - name: Get runner
    uses: alphagov/github-actions-runner-orchestration/client@main
    id: garoclient
    with:
      ACTION: 'start'
      GITHUB_TOKEN: '${{ secrets.GITHUB_TOKEN }}'
      RUNNER_TYPE: 'ondemand'
      REPO: '${{ github.repository }}'
      GITHUB_COMMIT: '${{ github.sha }}'
      RUNNER_SUBNET: '${{ secrets.RUNNER_SUBNET }}'
      RUNNER_SG: '${{ secrets.RUNNER_SG }}'
      RUNNER_ACID: '${{ secrets.RUNNER_ACID }}'
      RUNNER_EXID: '${{ secrets.RUNNER_EXID }}'
```
