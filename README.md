# github-actions-runner-orchestration ![Experimental](https://img.shields.io/badge/Status-Experimental-orange.svg)
GARO - serverless (AWS Lambda) GitHub Actions self-hosted EC2 runner orchestration tool

## What?
This is an experimental API for running ephemeral GitHub Action runners in EC2 instances.

## How?
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

#### Manual example of `/start` POST
This will eventually be replaced with an _easy-to-use_ JavaScript GitHub Action.

```sh
PARAMS="time=`date +%s`&type=ondemand&subnet=${{ secrets.RUNNER_SUBNET }}&sg=${{ secrets.RUNNER_SG }}&repo=alphagov/github-actions-runner-orchestration&timeout=900&account_id=${{ secrets.RUNNER_ACID }}&external_id=${{ secrets.RUNNER_EXID }}"
        
RUNNER=`curl --request POST \
  --header "Content-Type: application/x-www-form-urlencoded" \
  --header "X-GitHub-Token: ${{ secrets.GITHUB_TOKEN }}" \
  --header "X-GitHub-CommitSHA: $GITHUB_SHA" \
  --header "X-GitHub-Signature: $( \
      echo -n "$PARAMS" \
      | openssl dgst -sha512 -hmac "${{ secrets.GITHUB_TOKEN }}" -binary \
      | xxd -ps -c 64 )" \
  --data "$PARAMS" \
  https://gho-test.londonapps.digital/start`

if [ "$RUNNER" == "error" ] || [ "failure" == `echo -n "$RUNNER" | jq -r '.status'` ]; then
  echo 'Something went wrong:'
  echo "$RUNNER"
  exit 1
else
  echo "$RUNNER" | jq
fi
```
