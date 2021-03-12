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

    aws ec2 create-tags --region "$RUNNER_REGION" \
      --resources "$INSTANCE_ID" --tags "Key=RunnerState,Value=removing"

    RAWPAT=$(aws ssm get-parameter --name "/github/runner/pat" \
      --region "$RUNNER_REGION" --with-decryption \
      | jq -r ".[].Value" | tr -cd '[:print:]')

    export RUNNER_CFG_PAT=$RAWPAT

    sleep 120 && sudo shutdown -h now &

    ./remove-svc.sh "$RUNNER_REPO" "$RUNNER_NAME"
    sleep 10
    ./delete.sh "$RUNNER_REPO" "$RUNNER_NAME"
  fi
done
