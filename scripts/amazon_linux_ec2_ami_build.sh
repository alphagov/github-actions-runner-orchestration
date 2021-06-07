#!/usr/bin/env bash
echo "Starting user data"

# WARNING: everything in here will become available in the public AMI!

yum upgrade -y
rpm -Uvh https://packages.microsoft.com/config/centos/7/packages-microsoft-prod.rpm
yum install -y deltarpm
yum update -y
yum install -y jq git amazon-linux-extras tar gzip util-linux dotnet-sdk-5.0 \
  unzip sudo yum-utils xz zip openssl-devel libyaml-devel libffi-devel \
  readline-devel gdbm-devel ncurses-devel ruby-devel which procps nano \
  systemd
yum groupinstall -y "Development Tools"

echo "--------------"

EC2_TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 60")

curl -H "X-aws-ec2-metadata-token: $EC2_TOKEN" \
  "http://169.254.169.254/latest/meta-data/instance-id" > instance_id.txt

curl -H "X-aws-ec2-metadata-token: $EC2_TOKEN" \
  "http://169.254.169.254/latest/meta-data/placement/availability-zone" > az.txt

INSTANCE_ID=$(tr -cd '[:print:]' < instance_id.txt)
export INSTANCE_ID=$INSTANCE_ID

REGION=$(tr -cd '[:print:]' < az.txt | grep -oP "^(.+?\d(?=[a-z]))")
export REGION=$REGION

echo "Instance ID: $INSTANCE_ID, Region: $REGION"

echo "--------------"

aws ec2 create-tags --region "$REGION" \
  --resources "$INSTANCE_ID" --tags "Key=AMIBuildStatus,Value=starting"

echo "--------------"

curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "acv2.zip"
unzip -o acv2.zip
rm acv2.zip
sudo ./aws/install

GRD="/opt/github/runner"
RAWGITHUB="https://raw.githubusercontent.com"
GARO="alphagov/github-actions-runner-orchestration"

mkdir -p "$GRD"
cd "$GRD" || exit 1

echo "Adding github user"
useradd github
echo 'github ALL=(ALL) NOPASSWD: ALL' | sudo tee -a /etc/sudoers # pragma: allowlist secret

echo "Adding github user to docker group"
echo " * Docker is present in ECS AMI"
usermod -aG docker github

echo "Install rvm"
# Import key
runuser -l github -c "curl -sSL https://rvm.io/mpapis.asc | gpg2 --import - \
  && curl -sSL https://rvm.io/pkuczynski.asc | gpg2 --import -"
# Install RVM
runuser -l github -c 'curl -sSL https://get.rvm.io | bash -s stable --ruby --with-default-gems="rails"'

echo "Installing nvm"
NVMV="0.37.2"
runuser -l github -c "curl -so- 'https://raw.githubusercontent.com/nvm-sh/nvm/v$NVMV/install.sh' | bash"

echo "Installing rust"
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs > /opt/rust.sh
runuser -l github -c "sh /opt/rust.sh -y"
rm /opt/rust.sh

echo 'Install golang'
curl -sLO "https://golang.org/dl/go1.16.1.linux-amd64.tar.gz"
tar -C /usr/local -xzf ./go*.tar.gz
rm ./*.tar.gz

echo "Install GARO scripts"
GHLC="${RAWGITHUB}/${GARO}/main/scripts/install_headless_chrome.sh"
curl -sLO "$GHLC"
GURL="${RAWGITHUB}/${GARO}/main/scripts/instance_watcher.sh"
curl -sLO "$GURL"
chmod +x ./*.sh

echo "Installing docker-compose"
DCV="1.22.0"
curl -L "https://github.com/docker/compose/releases/download/$DCV/docker-compose-$(uname -s)-$(uname -m)" \
  -o "/usr/local/bin/docker-compose"
sudo chmod +x "/usr/local/bin/docker-compose"

echo "Installing ShellCheck"
scversion="stable"
curl -sLO "https://github.com/koalaman/shellcheck/releases/download/${scversion?}/shellcheck-${scversion?}.linux.x86_64.tar.xz"
tar -xvf ./*.tar.xz
cp "shellcheck-${scversion}/shellcheck" /usr/local/bin
rm -rf ./shellcheck*

echo "Installing python"
amazon-linux-extras enable python3.8
yum -y install python3.8

echo "Installing poetry"
POETRY_SHA="cc195f1dd086d1c4d12a3acc8d6766981ba431ac" # pragma: allowlist secret
runuser -l github -c "curl -sSL 'https://raw.githubusercontent.com/python-poetry/poetry/$POETRY_SHA/get-poetry.py' | python -"

echo "Installing tfenv tools"
git clone https://github.com/tfutils/tfenv.git "/opt/tfenv"
rm /usr/local/bin/tfenv || echo "No tfenv installed"
rm /usr/local/bin/terraform || echo "No terraform installed"
ln -s /opt/tfenv/bin/tfenv /usr/local/bin > /dev/null
ln -s /opt/tfenv/bin/terraform /usr/local/bin > /dev/null
chown github:github -R /opt/tfenv

echo "Downloading latest runner"
CURRENT_SHA="d4cdb633db046f3ec5da048feba940c3a8d606a6" # pragma: allowlist secret
CURRENT_URL="https://raw.githubusercontent.com/actions/runner/$CURRENT_SHA/scripts/"

curl -sLO "$CURRENT_URL/create-latest-svc.sh"
curl -sLO "$CURRENT_URL/delete.sh"
curl -sLO "$CURRENT_URL/remove-svc.sh"
chmod +x ./*.sh
chown github:github -R "$GRD"

echo "Adding environment variables"
# shellcheck disable=SC2016
(
  echo 'PATH="/home/github/.cargo/bin:/usr/local/go/bin:/usr/local/bin:/opt/github/runner:$PATH"'
  echo 'GOPATH=$HOME/go && export GOPATH'
  echo 'GO111MODULE="auto" && export GO111MODULE'
  echo 'export PATH'
  echo "redact () {
    if (( \$# > 0)); then
      MATCH=\$(echo \"\$@\" | sed 's/ /\|/') && \
        sed -E \"s/\$MATCH/REDACTED/g\";
    else read tmpRdt && echo \$tmpRdt;
    fi
  }"
  echo "awsredact () { redact '[[:xdigit:]]{9,999}'; }"
  echo "hexredact () { redact '[[:xdigit:]]{4,999}'; }"
) | tee -a /home/github/.bash_profile >> /home/github/.bashrc

chown github:github -R /home/github

echo "Cleaning up"
sudo yum clean all
sudo rm -rf /var/cache/yum

echo "ready" > /home/github/ami_state.txt

aws ec2 create-tags --region "$REGION" \
  --resources "$INSTANCE_ID" --tags "Key=AMIBuildStatus,Value=done"

echo "-------- Finished common ---------"
