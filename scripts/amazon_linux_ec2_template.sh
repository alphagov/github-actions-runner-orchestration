#!/usr/bin/env bash
echo "Starting user data"

GRD="/opt/github/runner"
mkdir -p "$GRD"
cd "$GRD" || exit 1

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

echo -n '{region}' > region.txt
echo -n 'github-runner-{type}-{uniqueid}' > name.txt
echo -n '{repo}' > repo.txt

REGION=$(tr -cd '[:print:]' < region.txt)
NAME=$(tr -cd '[:print:]' < name.txt)
REPO=$(tr -cd '[:print:]' < repo.txt)

export REGION=$REGION
export REPO=$REPO
export NAME=$NAME

yum update
yum install -y aws-cli jq

GARO="alphagov/github-actions-runner-orchestration"
GURL="https://raw.githubusercontent.com/$GARO/main/scripts/instance_watcher.sh"
curl -LO "$GURL"
chmod +x ./*.sh
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

echo "Installing GitHub runner dependencies"
rpm -Uvh https://packages.microsoft.com/config/centos/7/packages-microsoft-prod.rpm
yum update
yum install -y tar gzip util-linux dotnet-sdk-5.0 jq aws-cli

echo "Adding github user"
useradd github

echo "Downloading latest runner"

CURRENT_SHA="8109c962f09d9acc473d92c595ff43afceddb347"
CURRENT_URL="https://raw.githubusercontent.com/actions/runner/$CURRENT_SHA/scripts/"

curl -LO "$CURRENT_URL/create-latest-svc.sh"
curl -LO "$CURRENT_URL/delete.sh"
curl -LO "$CURRENT_URL/remove-svc.sh"
chmod +x ./*.sh
chown github:github -R "$GRD"

echo "-----------------"

timeout 60 ./create-latest-svc.sh "$REPO" '' "$NAME" \
  'github' '{type},{uniqueid}{additional}'

aws ec2 create-tags --region "$REGION" \
  --resources "$INSTANCE_ID" --tags "Key=RunnerState,Value=started"
