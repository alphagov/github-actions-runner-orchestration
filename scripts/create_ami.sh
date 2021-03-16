#!/usr/bin/env bash

echo "Starting: $(date +%s)"

REGION="eu-west-2"

echo "Getting lastest Amazon Linux 2 ECS AMI"
python3 -m pip install boto3
IMAGEID=$(python3 -c "from wrangling_ec2 import getLatestAmzn2Image; \
  import json; \
  ecs_ami = getLatestAmzn2Image('$REGION', {}); \
  print(json.dumps(ecs_ami, default=str))" | jq -r '.ImageId')

if [ -z "$IMAGEID" ] || [ "$IMAGEID" == "null" ]; then
  echo "Failed to get image ID"
  exit 1
fi

echo "Creating instance"
CREATE_EC2=$(aws ec2 run-instances \
  --region "$REGION" \
  --image-id "$IMAGEID" \
  --instance-type t3a.medium \
  --count 1 \
  --no-associate-public-ip-address \
  --subnet-id "$SUBNETID" \
  --security-group-ids "$SECURITYG" \
  --monitoring Enabled=true \
  --iam-instance-profile Name="GitHubRunnerInstanceRole" \
  --user-data "file://scripts/amazon_linux_ec2_ami_build.sh")

INSTANCE_ID=$(echo "$CREATE_EC2" | jq -r '.Instances[0].InstanceId')

echo "Created instance: $(date +%s)"
sleep 10

READY="false"

echo "Describing instance in while loop to check if ready"
i="0"
# 20 minutes
while [ $i -lt 40 ]; do
  AMIBUILDSTATUS=$(aws ec2 describe-tags \
    --filters "Name=resource-id,Values=$INSTANCE_ID" \
    --region "$REGION" \
    | jq -r '.Tags | .[] | select(.Key == "AMIBuildStatus").Value')

  if [ "$AMIBUILDSTATUS" == "done" ]; then
    READY="true"
    break
  else
    echo "Not ready: ${AMIBUILDSTATUS}"
    sleep 30
  fi

  i=$(( i + 1 ))
done

function terminateEC2 {
  aws ec2 terminate-instances \
    --region "$1" \
    --instance-ids "$2"
}

sleep 30

if [ "$READY" != "true" ]; then
  echo "EC2 wasn't ready in time"
  exit 1
fi

echo "EC2 instance ready, taking an image..."

AMI_ID=$(aws ec2 create-image \
  --region "$REGION" \
  --instance-id "$INSTANCE_ID" \
  --name "custom-ami-$(date +%s)" | jq -r '.ImageId')

if [ -z "$AMI_ID" ] || [ "$AMI_ID" == "null" ]; then
  echo "Failed to start creating the image"
  terminateEC2 "$REGION" "$INSTANCE_ID"
  exit 1
fi

echo "Created instance: $(date +%s)"

AMI_READY="false"
j="0"
# 10 minutes
while [ $j -lt 20 ]; do
  IMAGE_STATUS_JSON=$(aws ec2 describe-images \
      --region "$REGION" \
      --image-ids "$AMI_ID")

  AMI_STATUS=$(echo "$IMAGE_STATUS_JSON" | jq -r '.Images[0].State')

  if [ "$AMI_STATUS" == "available" ]; then
    AMI_READY="true"
    break
  else
    echo "Not ready: ${AMI_STATUS}"
    sleep 30
  fi

  j=$(( j + 1 ))
done

if [ "$AMI_READY" != "true" ]; then
  echo "AMI wasn't ready in time"
  terminateEC2 "$REGION" "$INSTANCE_ID"
  exit 1
fi

sleep 5

echo "Making AMI public"
aws ec2 modify-image-attribute \
  --image-id "$AMI_ID" \
  --region "$REGION" \
  --launch-permission "Add=[{Group=all}]"

sleep 1

echo "Terminating original EC2"
terminateEC2 "$REGION" "$INSTANCE_ID"

echo "-- FINISHED! --"
