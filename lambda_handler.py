import boto3
import traceback
import time
import json
import sys
import datetime

from wrangling_ec2 import *
from wrestling_sts import *
from github import *
from http_helper import *
from utils import envVar


def lambda_handler(event, context):
    """

    >>> t = lambda_handler({}, {})
    >>> "Error" not in t
    True

    """

    actresp = actual_handler(event, context)

    error = None
    if "Error" in actresp:
        error = actresp.pop("Error")

    with_redaction = True
    debug = envVar("DEBUG")
    if debug and debug == "1":
        with_redaction = False

    logEvent(event, actresp, error, with_redaction=with_redaction)
    return actresp


def actual_handler(event, context):
    """

    >>> t = actual_handler({}, {})
    >>> "Error" in t
    True
    >>> t["Error"].startswith("Missing path")
    True

    >>> t = actual_handler({"path": "/status"}, {})
    >>> "Error" not in t
    True
    >>> 200 == t["statusCode"]
    True
    >>> "ok" in t["body"]
    True

    >>> with open('tests/fixtures/example.json') as json_file:
    ...   example = json.load(json_file)
    >>> "httpMethod" in example
    True
    >>> t = actual_handler(example, {})
    >>> t["Error"].startswith("Missing X-GitHub-Token")
    True

    """

    try:
        response = {}

        path = ""
        if "path" in event:
            path = event["path"]
            if path not in ("/start", "/status", "/stop", "/state"):
                raise Exception("Unknown path")
        else:
            raise Exception("Missing path")

        if path == "/status":
            return {
                "statusCode": 200,
                "isBase64Encoded": False,
                "headers": {"Content-Type": "application/json"},
                "body": '{"status": "ok"}',
            }

        if "x-github-token" not in event["headers"]:
            raise Exception("Missing X-GitHub-Token")

        if "x-github-commitsha" not in event["headers"]:
            raise Exception("Missing X-GitHub-CommitSHA")

        if "x-github-signature" not in event["headers"]:
            raise Exception("Missing X-GitHub-Signature")

        body_qs = extractAndValidateBody(
            event["body"],
            signature=event["headers"]["x-github-signature"],
            isBase64=event["isBase64Encoded"],
            with_validate=False,
        )

        token_check = checkGitHubToken(
            body_qs["repo"],
            event["headers"]["x-github-token"],
            event["headers"]["x-github-commitsha"],
        )

        if not token_check:
            raise Exception(f"Failed the token check for: {body_qs['repo']}")

        # do authenticated AWS actions from here on

        credentials = assumeRole(body_qs)
        if "AccessKeyId" not in credentials:
            raise Exception("bad credentials")

        if path == "/start":
            ec2 = startRunnerFromBody(body_qs, credentials)

            if not ec2:
                raise Exception(f"Failed to start an instance for: {body_qs['repo']}")

            return {
                "statusCode": 200,
                "isBase64Encoded": False,
                "headers": {"Content-Type": "application/json"},
                "body": json.dumps(ec2, default=str),
            }

        if path == "/state":
            running_ec2 = currentRunnerExistsByBody(body_qs, credentials)

            if not running_ec2:
                raise Exception(f"Failed to details for: {body_qs['name']}")

            # TODO: check ready tag
            if "region" in body_qs:
                region = body_qs["region"]
            else:
                region = ""

            state = getRunnerStateTag(running_ec2["InstanceId"], region, credentials)

            running_ec2["State"] = state

            return {
                "statusCode": 200,
                "isBase64Encoded": False,
                "headers": {"Content-Type": "application/json"},
                "body": json.dumps(running_ec2, default=str),
            }

    except Exception as e:
        return {
            "statusCode": 500,
            "body": "error",
            "Error": f"{e}\n\n{traceback.format_exc()}",
        }


def logEvent(request: dict, response: dict, error: str, with_redaction=True) -> str:
    """
    This logs request from ALB and response back to a JSONL for CloudWatch ingestion

    >>> res = logEvent({}, {}, "")
    >>> exp = { \
          "req": {}, \
          "res": {} \
        }
    >>> jr = json.loads(res)
    >>> jr.pop("time") > 0
    True
    >>> jr == exp
    True

    >>> res = logEvent( \
                {"httpMethod": "POST", "body": "234"}, \
                {"statusCode": 200, "body": "good"}, \
                "abc", with_redaction=False \
              )
    >>> exp = { \
          "error": "abc", \
          "req": {"httpMethod": "POST", "body": "234"}, \
          "res": {"statusCode": 200, "body": "good"} \
        }
    >>> jr = json.loads(res)
    >>> t = jr.pop("time")
    >>> type(t)
    <class 'int'>
    >>> t > 0
    True
    >>> jr == exp
    True

    >>> res = logEvent( \
                {"httpMethod": "POST", "body": "123"}, \
                {"statusCode": 500, "body": "bad"}, \
                "abc" \
              )
    >>> exp = { \
          "error": "abc", \
          "req": {"httpMethod": "POST", "body": "REDACTED"}, \
          "res": {"statusCode": 500, "body": "REDACTED"} \
        }
    >>> jr = json.loads(res)
    >>> t = jr.pop("time")
    >>> type(t)
    <class 'int'>
    >>> t > 0
    True
    >>> jr == exp
    True

    """

    lg = {
        "time": int(time.time()),
        "req": request,
        "res": response,
    }
    if error:
        lg["error"] = error

    if with_redaction:
        redacted = "REDACTED"

        if "headers" in lg["req"]:
            if "x-github-token" in lg["req"]["headers"]:
                lg["req"]["headers"]["x-github-token"] = redacted

        if "body" in lg["req"]:
            lg["req"]["body"] = redacted

        if "body" in lg["res"]:
            lg["res"]["body"] = redacted

    res = json.dumps(lg, default=str)
    print(res, file=sys.stderr)
    return res
