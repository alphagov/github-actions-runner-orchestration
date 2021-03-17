#!/usr/bin/env bash

while true; do
  sleep 30

  cd "/opt/github/runner" || exit 1

  INSTANCE_ID=$(tr -cd '[:print:]' < instance_id.txt)
  RUNNER_REGION=$(tr -cd '[:print:]' < region.txt)
  RUNNER_REPO=$(tr -cd '[:print:]' < repo.txt)
  RUNNER_NAME=$(tr -cd '[:print:]' < name.txt)

  export INSTANCE_ID=$INSTANCE_ID
  export RUNNER_REGION=$RUNNER_REGION
  export RUNNER_REPO=$RUNNER_REPO
  export RUNNER_NAME=$RUNNER_NAME

  EXPIRY=$(aws ec2 describe-tags \
    --filters "Name=resource-id,Values=$INSTANCE_ID" \
    --region "$RUNNER_REGION" \
    | jq -r '.Tags | .[] | select(.Key == "GitHubRunnerTimeout").Value')

  if (( EXPIRY < $(date +%s) )); then
    echo "------------------"
    echo "Shutting down, expiry was: $EXPIRY"
    echo "------------------"

    # schedule a shutdown before doing anything else:
    sleep 60 && sudo shutdown -h now &

    aws ec2 create-tags --region "$RUNNER_REGION" \
      --resources "$INSTANCE_ID" --tags "Key=RunnerState,Value=removing"

    RAWPAT=$(aws ssm get-parameter --name "/github/runner/pat" \
      --region "$RUNNER_REGION" --with-decryption \
      | jq -r ".[].Value" | tr -cd '[:print:]')

    RUNNER_CFG_PAT=$RAWPAT
    export RUNNER_CFG_PAT=$RAWPAT

    # the following is adapted from:
    # https://github.com/actions/runner/blob/main/scripts/remove-svc.sh

    TOKEN_ENDPOINT="https://api.github.com/repos/${RUNNER_REPO}/actions/runners/remove-token"

    REMOVE_TOKEN=$(curl -s -X POST "$TOKEN_ENDPOINT" \
      -H "accept: application/vnd.github.everest-preview+json" \
      -H "authorization: token ${RUNNER_CFG_PAT}" | jq -r '.token')
    export REMOVE_TOKEN=$REMOVE_TOKEN

    if [ -z "$REMOVE_TOKEN" ]; then echo "Failed to get a token" && exit 1; fi

    # GitHub uses node to run the runner, kill it
    sudo killall node
    sleep 5

    echo
    echo "Removing the runner..."
    pushd ./runner || exit 1
    runuser -l github -c "./config.sh remove --token $REMOVE_TOKEN"
  fi
done
