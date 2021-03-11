#!/usr/bin/env bash
echo "Starting user data"

curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "acv2.zip"
unzip acv2.zip
sudo ./aws/install

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

aws ec2 create-tags --region "$REGION" \
  --resources "$INSTANCE_ID" --tags "Key=RunnerState,Value=installing"

yum update -y
yum install -y jq git amazon-linux-extras

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


echo "Adding github user"
useradd github
echo 'github ALL=(ALL) NOPASSWD: ALL' | sudo tee -a /etc/sudoers # pragma: allowlist secret


echo "Installing common tools"

sudo amazon-linux-extras enable python3.8
sudo yum -y install python3.8

git clone https://github.com/tfutils/tfenv.git ~/.tfenv
sudo rm /usr/local/bin/tfenv || echo "No tfenv installed"
sudo rm /usr/local/bin/terraform || echo "No terraform installed"
sudo ln -s ~/.tfenv/bin/* /usr/local/bin > /dev/null

POETRY_SHA="cc195f1dd086d1c4d12a3acc8d6766981ba431ac" # pragma: allowlist secret
runuser -l github -c "curl -sSL 'https://raw.githubusercontent.com/python-poetry/poetry/$POETRY_SHA/get-poetry.py' | python -"

echo "Installing GitHub runner dependencies"
rpm -Uvh https://packages.microsoft.com/config/centos/7/packages-microsoft-prod.rpm
yum update -y
yum install -y tar gzip util-linux dotnet-sdk-5.0


echo "Downloading latest runner"
CURRENT_SHA="8109c962f09d9acc473d92c595ff43afceddb347" # pragma: allowlist secret
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
