#!/usr/bin/env bash
echo "Starting user data"

GRD="/opt/github/runner"
mkdir -p "$GRD"
cd "$GRD" || exit 1

RAWGITHUB="https://raw.githubusercontent.com"
GARO="alphagov/github-actions-runner-orchestration"

GURL="$RAWGITHUB/$GARO/main/scripts/amazon_linux_ec2_ami_build.sh"
curl -sLO "$GURL"
chmod +x ./*.sh

./amazon_linux_ec2_ami_build.sh

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

REGION=$(tr -cd '[:print:]' < region.txt)
NAME=$(tr -cd '[:print:]' < name.txt)
REPO=$(tr -cd '[:print:]' < repo.txt)

export REGION=$REGION
export REPO=$REPO
export NAME=$NAME

aws ec2 create-tags --region "$REGION" \
  --resources "$INSTANCE_ID" --tags "Key=RunnerState,Value=installing"

echo "------- Start the watcher -------"

./instance_watcher.sh &

echo "Getting PAT from SSM '/github/runner/pat'"
RAWPAT=$(aws ssm get-parameter --name "/github/runner/pat" --region "$REGION" \
  --with-decryption | jq -r ".[].Value" | tr -cd '[:print:]')
export RUNNER_CFG_PAT=$RAWPAT

if [ -z "$RUNNER_CFG_PAT" ]
then
  aws ec2 create-tags --region "$REGION" \
    --resources "$INSTANCE_ID" --tags "Key=RunnerState,Value=bad-ssm-access"
  sudo shutdown -h now
fi

echo "-----------------"

timeout 60 ./create-latest-svc.sh "$REPO" '' "$NAME" \
  'github' '{type},{uniqueid},{additional}'

aws ec2 create-tags --region "$REGION" \
  --resources "$INSTANCE_ID" --tags "Key=RunnerState,Value=started"
