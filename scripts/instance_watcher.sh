#!/usr/bin/env bash

while true; do
  sleep 30

  cd "/opt/github/runner" || exit 1

  INSTANCE_ID=$(tr -cd '[:print:]' < instance_id.txt)
  REGION=$(tr -cd '[:print:]' < region.txt)
  REPO=$(tr -cd '[:print:]' < repo.txt)
  NAME=$(tr -cd '[:print:]' < name.txt)

  export INSTANCE_ID=$INSTANCE_ID
  export REGION=$REGION
  export REPO=$REPO
  export NAME=$NAME

  EXPIRY=$(aws ec2 describe-tags \
    --filters "Name=resource-id,Values=$INSTANCE_ID" \
    --region "$REGION" \
    | jq -r '.Tags | .[] | select(.Key == "GitHubRunnerTimeout").Value')

  if (( EXPIRY < $(date +%s) )); then
    echo "------------------"
    echo "Shutting down, expiry was: $EXPIRY"
    echo "------------------"

    aws ec2 create-tags --region "$REGION" \
      --resources "$INSTANCE_ID" --tags "Key=RunnerState,Value=removing"

    RAWPAT=$(aws ssm get-parameter --name "/github/runner/pat" --region "$REGION" \
      --with-decryption | jq -r ".[].Value" | tr -cd '[:print:]')

    export RUNNER_CFG_PAT=$RAWPAT

    sleep 120 && sudo shutdown -h now &

    ./remove-svc.sh "$REPO"
    sleep 10
    ./delete.sh "$REPO" "$NAME"
  fi
done
