#!/usr/bin/env bash
echo "Starting user data"

GRD="/opt/github/runner"
cd "$GRD" || exit 1

if [ "$(cat /home/github/ami_state.txt)" != "ready" ]; then
  sudo shutdown -h now || exit 1
fi

echo "--------------"

EC2_TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 60")

curl -H "X-aws-ec2-metadata-token: $EC2_TOKEN" \
  -v "http://169.254.169.254/latest/meta-data/instance-id" > instance_id.txt

INSTANCE_ID=$(tr -cd '[:print:]' < instance_id.txt)
export INSTANCE_ID=$INSTANCE_ID

echo "Instance ID: $INSTANCE_ID"

if [ -z "$INSTANCE_ID" ]
then
  sudo shutdown -h now
fi

echo "--------------"

echo -n '{region}' > region.txt
echo -n 'github-runner-{type}-{uniqueid}' > name.txt
echo -n '{repo}' > repo.txt

RUNNER_REGION=$(tr -cd '[:print:]' < region.txt)
RUNNER_NAME=$(tr -cd '[:print:]' < name.txt)
RUNNER_REPO=$(tr -cd '[:print:]' < repo.txt)

export RUNNER_REGION=$RUNNER_REGION
export RUNNER_REPO=$RUNNER_REPO
export RUNNER_NAME=$RUNNER_NAME

aws ec2 create-tags --region "$RUNNER_REGION" \
  --resources "$INSTANCE_ID" --tags "Key=RunnerState,Value=installing"

echo "------- Start the watcher -------"

./instance_watcher.sh &

echo "Getting PAT from SSM '/github/runner/pat'"
RAWPAT=$(aws ssm get-parameter --name "/github/runner/pat" --region "$RUNNER_REGION" \
  --with-decryption | jq -r ".[].Value" | tr -cd '[:print:]')
export RUNNER_CFG_PAT=$RAWPAT

if [ -z "$RUNNER_CFG_PAT" ]
then
  aws ec2 create-tags --region "$RUNNER_REGION" \
    --resources "$INSTANCE_ID" --tags "Key=RunnerState,Value=bad-ssm-access"
  sudo shutdown -h now
fi

echo "-----------------"

timeout 60 ./create-latest-svc.sh "$RUNNER_REPO" '' "$RUNNER_NAME" \
  'github' '{type},{uniqueid}{additional}'

aws ec2 create-tags --region "$RUNNER_REGION" \
  --resources "$INSTANCE_ID" --tags "Key=RunnerState,Value=started"
