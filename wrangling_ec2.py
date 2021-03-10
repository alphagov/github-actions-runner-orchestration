import boto3
import datetime
import time
import base64
import json
import re
import botocore

from utils import random_string

EC2_DEFAULT_TYPE: str = "spot"
EC2_DEFAULT_INSTANCEROLEARN: str = "GitHubRunnerInstanceRole"
EC2_DEFAULT_INSTANCETYPE: str = "t2.micro"
EC2_DEFAULT_REGION: str = "eu-west-2"
EC2_DEFAULT_TIMEOUT: int = 3600


def buildRunnerUserData2(
    repo: str,
    type: str,
    uniqueid: str,
    label: str = "",
    region: str = EC2_DEFAULT_REGION,
):
    """
    Builds the runner specific user data as base64

    >>> b64 = buildRunnerUserData2("abc", "123", "678", "def")
    >>> len(b64) > 0
    True
    >>> txt = base64.b64decode(b64).decode("utf-8")
    >>> "'github' '123,678,def'" in txt
    True

    >>> b64 = buildRunnerUserData2("cba", "123", "678")
    >>> len(b64) > 0
    True
    >>> txt = base64.b64decode(b64).decode("utf-8")
    >>> "'github' '123,678'" in txt
    True
    >>> "export RUNNER_CFG_PAT=$RAWPAT" in txt
    True

    """

    additional = ""
    if label:
        if label.isalnum():
            additional = f",{label}"

    # TODO: generate a custom AMI with packages downloaded and use that instead

    runner = None

    with open("scripts/amazon_linux_ec2_template.sh", "r") as file:
        runner = f"{file.read()}".format(**locals())

    if not runner:
        return None

    enc = "utf-8"
    return base64.b64encode(runner.replace("\n\n", "\n").encode(enc)).decode(enc)


def getLatestAmzn2Image(region: str, credentials: dict) -> dict:

    client = getEc2Client(credentials, region)

    response = client.describe_images(
        Owners=["amazon"],
        Filters=[
            {"Name": "name", "Values": ["amzn2-ami-hvm-2.?.20??????.0-x86_64-gp2"]},
            {"Name": "state", "Values": ["available"]},
        ],
    )

    if "Images" in response and len(response["Images"]) > 0:
        res_image = {}
        current_datetime = datetime.datetime(1970, 1, 1)

        for image in response["Images"]:

            dt = datetime.datetime.strptime(
                image["CreationDate"], "%Y-%m-%dT%H:%M:%S.%fZ"
            )

            if dt > current_datetime:
                current_datetime = dt
                res_image = image

        return res_image

    raise Exception("Error getting latest Amazon Linux 2")


def updateTimeoutTag(
    instanceid: str, timeout: int, region: str, credentials: dict
) -> str:
    if not region:
        region = EC2_DEFAULT_REGION

    grt = _timeoutTagValue(timeout)

    client = getEc2Client(credentials, region)

    response = client.create_tags(
        Resources=[instanceid], Tags=[{"Key": "GitHubRunnerTimeout", "Value": grt}],
    )

    if "ResponseMetadata" in response:
        return grt

    return None


def currentRunnerExistsByBody(body_qs: dict, credentials: dict) -> str:
    name = body_qs["name"]

    if "region" in body_qs:
        region = body_qs["region"]
    else:
        region = EC2_DEFAULT_REGION

    filters = [{"Name": "tag:Name", "Values": [name]}]

    return _currentRunnerExists(filters, region, credentials)


def currentRunnerExistsByType(
    type: str, additional_label: str, region: str, credentials: dict,
) -> str:
    filters = [
        {"Name": "tag:Name", "Values": [f"github-runner-{type}-*"]},
    ]

    if additional_label:
        filters.append({"Name": "tag:Label", "Values": [additional_label]})

    return _currentRunnerExists(filters, region, credentials)


def _currentRunnerExists(filters: list, region: str, credentials: dict) -> dict:
    client = getEc2Client(credentials, region)

    filters.append({"Name": "tag:RunnerState", "Values": ["star*"]})
    filters.append({"Name": "instance-state-name", "Values": ["pending", "running"]})

    response = client.describe_instances(Filters=filters, MaxResults=30)

    res = {}

    if "Reservations" in response:
        if len(response["Reservations"]) >= 1:
            if "Instances" in response["Reservations"][0]:
                if len(response["Reservations"][0]["Instances"]) >= 1:

                    res.update(
                        {
                            "instanceid": response["Reservations"][0]["Instances"][0][
                                "InstanceId"
                            ]
                        }
                    )

                    tags = response["Reservations"][0]["Instances"][0]["Tags"]

                    for tag in tags:
                        if tag["Key"] == "Name":
                            res.update({"name": tag["Value"]})

                        if tag["Key"] == "GitHubRunnerTimeout":
                            res.update({"updated_expiry_time": tag["Value"]})

                        if tag["Key"] == "RunnerState":
                            res.update({"runnerstate": tag["Value"]})

    return res


def startRunnerFromBody(body_items: dict, credentials: dict) -> bool:
    repo = body_items["repo"]
    sg = body_items["sg"]
    subnet = body_items["subnet"]

    if "type" in body_items:
        type = body_items["type"]
    else:
        type = EC2_DEFAULT_TYPE

    if "label" in body_items:
        additional_label = body_items["label"]
    else:
        additional_label = ""

    if "region" in body_items:
        region = body_items["region"]
    else:
        region = EC2_DEFAULT_REGION

    if "timeout" in body_items:
        timeout = int(body_items["timeout"])
    else:
        timeout = EC2_DEFAULT_TIMEOUT

    cre = currentRunnerExistsByType(type, additional_label, region, credentials)
    if cre:
        if "updated_expiry_time" in cre:
            # if the timeout has more than 45 seconds left:
            if int(cre["updated_expiry_time"]) >= int(time.time()) + 45:
                utt = updateTimeoutTag(cre["instanceid"], timeout, region, credentials)
                if utt:
                    cre.update(
                        {
                            "additional_label": additional_label,
                            "type": type,
                            "updated_expiry_time": utt,
                        }
                    )
                    return cre

    if "instanceRoleArn" in body_items:
        instanceRoleArn = body_items["instanceRoleArn"]
    else:
        instanceRoleArn = EC2_DEFAULT_INSTANCEROLEARN

    if "instanceType" in body_items:
        instanceType = body_items["instanceType"]
    else:
        instanceType = EC2_DEFAULT_INSTANCETYPE

    if "imageid" in body_items:
        imageid = body_items["imageid"]
    else:
        imageRes = getLatestAmzn2Image(region, credentials)
        imageid = imageRes["ImageId"]

    uniqueid = random_string(10)

    userDataB64 = buildRunnerUserData2(
        repo=repo, type=type, uniqueid=uniqueid, label=additional_label,
    )

    name = f"github-runner-{type}-{uniqueid}"

    result = startRunner(
        name=name,
        userdata=userDataB64,
        imageid=imageid,
        sg=sg,
        subnet=subnet,
        uniqueid=uniqueid,
        additional_label=additional_label,
        type=type,
        instanceRoleArn=instanceRoleArn,
        instanceType=instanceType,
        region=region,
        timeout=timeout,
        credentials=credentials,
    )
    return {
        "runnerstate": "starting",
        "name": name,
        "additional_label": additional_label,
        "type": type,
    }


def _timeoutTagValue(timeout: int = EC2_DEFAULT_TIMEOUT):
    return str(int(time.time()) + timeout)


def startRunner(
    name: str,
    userdata: str,
    imageid: str,
    sg: str,
    subnet: str,
    uniqueid: str,
    additional_label: str = "",
    type: str = EC2_DEFAULT_TYPE,
    instanceRoleArn: str = EC2_DEFAULT_INSTANCEROLEARN,
    instanceType: str = EC2_DEFAULT_INSTANCETYPE,
    region: str = EC2_DEFAULT_REGION,
    timeout: int = EC2_DEFAULT_TIMEOUT,
    credentials: dict = {},
) -> bool:

    expiry_time = _timeoutTagValue(timeout)

    if type == "spot":
        return _startSpotRunner(
            name,
            userdata,
            imageid,
            sg,
            subnet,
            uniqueid,
            additional_label,
            instanceRoleArn,
            instanceType,
            region,
            expiry_time,
            credentials,
        )

    if type == "ondemand":
        return _startOndemandRunner(
            name,
            userdata,
            imageid,
            sg,
            subnet,
            uniqueid,
            additional_label,
            instanceRoleArn,
            instanceType,
            region,
            expiry_time,
            credentials,
        )

    raise Exception("Type not recognised")


def _startOndemandRunner(
    name: str,
    userdata: str,
    imageid: str,
    sg: str,
    subnet: str,
    uniqueid: str,
    additional_label: str,
    instanceRoleArn: str,
    instanceType: str,
    region: str,
    expiry_time: int,
    credentials: dict,
) -> bool:

    client = getEc2Client(credentials, region)

    tags = [
        {"Key": "Name", "Value": name},
        {"Key": "UniqueID", "Value": uniqueid},
        {"Key": "GitHubRunnerTimeout", "Value": expiry_time},
        {"Key": "RunnerState", "Value": "pending"},
    ]

    response = client.run_instances(
        DryRun=False,
        ClientToken=uniqueid,
        MinCount=1,
        MaxCount=1,
        InstanceType=instanceType,
        TagSpecifications=[{"ResourceType": "instance", "Tags": tags}],
        UserData=userdata,
        ImageId=imageid,
        IamInstanceProfile={"Name": instanceRoleArn},
        InstanceInitiatedShutdownBehavior="terminate",
        NetworkInterfaces=[{"DeviceIndex": 0, "Groups": [sg], "SubnetId": subnet}],
        HibernationOptions={"Configured": False},
    )

    instance_created = False

    if "Instances" in response:
        if len(response["Instances"]) == 1:
            instance_created = True

    return instance_created


def _startSpotRunner(
    name: str,
    userdata: str,
    imageid: str,
    sg: str,
    subnet: str,
    uniqueid: str,
    additional_label: str,
    instanceRoleArn: str,
    instanceType: str,
    region: str,
    expiry_time: str,
    credentials: dict,
) -> bool:

    client = getEc2Client(credentials, region)

    response = client.request_spot_instances(
        DryRun=False,
        ClientToken=uniqueid,
        AvailabilityZoneGroup=region,
        InstanceCount=1,
        Type="one-time",
        LaunchSpecification={
            "IamInstanceProfile": {"Name": instanceRoleArn},
            "UserData": userdata,
            "ImageId": imageid,
            "InstanceType": instanceType,
            "Monitoring": {"Enabled": True},
            "NetworkInterfaces": [
                {"Groups": [sg], "SubnetId": subnet, "DeviceIndex": 0,}
            ],
        },
        TagSpecifications=[
            {
                "ResourceType": "spot-instances-request",
                "Tags": [{"Key": "Name", "Value": name}],
            }
        ],
    )

    spot_instance_created = False

    if "SpotInstanceRequests" in response:
        if len(response["SpotInstanceRequests"]) == 1:
            res = "first"
            counter = 1

            tags = [
                {"Key": "Name", "Value": name},
                {"Key": "UniqueID", "Value": uniqueid},
                {"Key": "GitHubRunnerTimeout", "Value": expiry_time},
                {"Key": "RunnerState", "Value": "pending"},
            ]

            if additional_label:
                tags.append({"Key": "Label", "Value": additional_label})

            # try up to six times
            while counter >= 6 or res != "done":
                res = _setSpotTagsFromRequest(
                    response["SpotInstanceRequests"][0]["SpotInstanceRequestId"],
                    tags,
                    region=region,
                    credentials=credentials,
                )

                print(f"setTags attempt {counter}: {res}")

                if res == "done":
                    spot_instance_created = True
                    break
                else:
                    time.sleep(2)
                counter += 1

    return spot_instance_created


def getEc2Client(credentials: dict = {}, region: str = EC2_DEFAULT_REGION):
    """

    Return the EC2 boto3 client, using shell credentials or temp credentials as a dict

    >>> try:
    ...   c = getEc2Client({"AccessKeyId": "123", "SecretAccessKey": "456", "SessionToken": "789"})
    ...   c.describe_images()
    ... except botocore.exceptions.ClientError as e:
    ...   "AuthFailure" in str(e)
    True

    """

    if credentials:
        client = boto3.client(
            "ec2",
            region_name=region,
            aws_access_key_id=credentials["AccessKeyId"],
            aws_secret_access_key=credentials["SecretAccessKey"],
            aws_session_token=credentials["SessionToken"],
        )
    else:
        client = boto3.client("ec2", region_name=region)

    return client


def _setSpotTagsFromRequest(
    instanceRequestId: str, tags: list, region: str, credentials: dict
) -> str:

    client = getEc2Client(credentials, region)

    response_desc = client.describe_spot_instance_requests(
        SpotInstanceRequestIds=[instanceRequestId]
    )

    if "SpotInstanceRequests" in response_desc:
        if len(response_desc["SpotInstanceRequests"]) == 1:
            if "InstanceId" in response_desc["SpotInstanceRequests"][0]:
                response_tags = client.create_tags(
                    Resources=[response_desc["SpotInstanceRequests"][0]["InstanceId"]],
                    Tags=tags,
                )
                return "done"
            else:
                return "tryagain"
    return "error"
