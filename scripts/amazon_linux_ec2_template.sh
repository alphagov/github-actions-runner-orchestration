#!/usr/bin/env bash
echo "Starting user data"

EC2_TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 60")

INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $EC2_TOKEN" \
  -v "http://169.254.169.254/latest/meta-data/instance-id")

export INSTANCE_ID=$INSTANCE_ID

if [ -z "$INSTANCE_ID" ]
then
  sudo shutdown -h now
fi

export NAME='github-runner-{type}-{uniqueid}'
export REPO='{repo}'

GRD="/opt/github/runner"
mkdir -p "$GRD"
cd "$GRD" || exit 1

yum update
yum install -y aws-cli jq

GARO="alphagov/github-actions-runner-orchestration"
GURL="https://raw.githubusercontent.com/$GARO/main/scripts/instance_watcher.sh"
curl -LO "$GURL"
chmod +x ./*.sh
./test_runner_shutdown_script.sh &

echo "Getting PAT from SSM '/github/runner/pat'"
RAWPAT=$(aws ssm get-parameter --name "/github/runner/pat" --region '{region}' \
  --with-decryption | jq -r ".[].Value")

export RUNNER_CFG_PAT=$RAWPAT

if [ -z "$RUNNER_CFG_PAT" ]
then
  sudo shutdown -h now
fi

echo "Installing GitHub runner dependencies"
rpm -Uvh https://packages.microsoft.com/config/centos/7/packages-microsoft-prod.rpm
yum update
yum install -y tar gzip util-linux dotnet-sdk-5.0 jq aws-cli

echo "Adding github user"
useradd github
# shellcheck disable=SC1054
{{
  echo "export RUNNER_CFG_PAT='$RAWPAT'"
  echo "export NAME='$NAME'"
  echo "export REPO='$REPO'"
}} >> /home/github/.bash_profile

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

aws ec2 create-tags --region '{region}' \
  --resources "$INSTANCE_ID" --tags "Key=RunnerState,Value=started"
