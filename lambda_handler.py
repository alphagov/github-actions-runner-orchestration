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


github_url = "https://github.com/alphagov/github-actions-runner-orchestration"


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
    >>> t["Error"].startswith("httpMethod not set")
    True

    >>> t = actual_handler({"path": "/", "httpMethod": "GET"}, {})
    >>> "Error" not in t
    True
    >>> 302 == t["statusCode"]
    True
    >>> github_url in t["body"]
    True
    >>> github_url in t["headers"]["Location"]
    True

    >>> t = actual_handler({"path": "/status", "httpMethod": "GET"}, {})
    >>> "Error" not in t
    True
    >>> 200 == t["statusCode"]
    True
    >>> "ok" in t["body"]
    True

    >>> t = actual_handler({"path": "/", "httpMethod": "POST"}, {})
    >>> 405 == t["statusCode"]
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

        method = None
        if "httpMethod" in event:
            method = event["httpMethod"]
        else:
            raise Exception("httpMethod not set")

        path = ""
        if "path" in event:
            path = event["path"]
            if path not in ("/start", "/status", "/stop", "/state"):
                # unknown path, reset:
                path = ""

        if path == "/status" and method == "GET":
            return {
                "statusCode": 200,
                "isBase64Encoded": False,
                "headers": {"Content-Type": "application/json"},
                "body": '{"status": "ok"}',
            }

        # if path is not set, handle here:
        if not path:
            if method == "GET":
                return {
                    "statusCode": 302,
                    "isBase64Encoded": False,
                    "headers": {"Location": github_url, "Content-Type": "text/html"},
                    "body": f'<a href="{github_url}">{github_url}</a>',
                }
            else:
                return {
                    "statusCode": 405,
                    "isBase64Encoded": False,
                    "headers": {"Content-Type": "text/html"},
                    "body": "Method Not Allowed",
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

        if path == "/start" and method == "POST":
            ec2 = startRunnerFromBody(body_qs, credentials)

            if not ec2:
                raise Exception(f"Failed to start an instance for: {body_qs['repo']}")

            return {
                "statusCode": 200,
                "isBase64Encoded": False,
                "headers": {"Content-Type": "application/json"},
                "body": json.dumps(ec2, default=str),
            }

        if path == "/state" and method == "POST":
            running_ec2 = currentRunnerExistsByBody(body_qs, credentials)

            if not running_ec2:
                raise Exception(f"Failed to details for: {body_qs['name']}")

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

    res = json.dumps(lg, default=str)

    if with_redaction:
        redacted = "REDACTED"

        if "headers" in request:
            if "x-github-token" in request["headers"]:
                res = res.replace(request["headers"]["x-github-token"], redacted)

        if "body" in request:
            res = res.replace(request["body"], redacted)

        if "body" in response:
            res = res.replace(response["body"], redacted)

    print(res, file=sys.stderr)
    return res
