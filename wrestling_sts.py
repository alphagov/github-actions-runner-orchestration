import boto3
import time
import botocore


ROLE_DEFAULT = ""
STS_DEFAULT_REGION: str = "eu-west-2"
STS_DEFAULT_TIMEOUT: int = 3600


def _getStsClient(region: str):
    """

    Return the STS boto3 client, using shell/Lambda credentials

    """
    client = boto3.client("sts", region_name=region)
    return client


def currentCaller(region: str = STS_DEFAULT_REGION) -> dict:
    """

    Return the IAM boto3 client, using shell/Lambda credentials

    >>> try:
    ...   c = currentCaller()
    ... except botocore.exceptions.ClientError as e:
    ...   print("Test requires AWS account to run sts get-caller-identity")
    >>> "UserId" in c
    True

    """
    sts = _getStsClient(region)
    return sts.get_caller_identity()


def assumeRole(body_qs: dict) -> dict:

    if "account_id" in body_qs:
        account_id = body_qs["account_id"]
    else:
        raise Exception("account_id not set")

    if "external_id" in body_qs:
        external_id = body_qs["external_id"]
    else:
        raise Exception("external_id not set")

    if "region" in body_qs:
        region = body_qs["region"]
    else:
        region = STS_DEFAULT_REGION

    if "timeout" in body_qs:
        timeout = int(body_qs["timeout"])
    else:
        timeout = STS_DEFAULT_TIMEOUT

    caller = currentCaller(region)
    if "Account" not in caller:
        raise Exception("get_caller_identity account failure")

    sts = _getStsClient(region)

    if timeout < 900:
        timeout = 900

    if timeout > 43200:
        timeout = 43200

    response = sts.assume_role(
        RoleArn=f"arn:aws:iam::{account_id}:role/GitHubRunnerAssumeRole",
        RoleSessionName=f'{caller["Account"]}-{int(time.time())}',
        DurationSeconds=timeout,
        ExternalId=external_id,
    )

    if "Credentials" in response:
        return response["Credentials"]

    raise Exception("failed to assume role")
