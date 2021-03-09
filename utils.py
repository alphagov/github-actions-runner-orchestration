import boto3
import os
import random
import string
import re

from base64 import b64decode


def envVar(env: str) -> str:
    """

    Gets a environment variable (or encrypted blob)

    >>> len(envVar("PATH")) > 1
    True

    >>> None is envVar("NONEXISTENTVARIABLEPROBABLY")
    True

    """
    if env and env in os.environ:
        return os.environ[env]
    return None


def decryptEnvVar(env: str) -> str:
    return (
        boto3.client("kms")
        .decrypt(
            CiphertextBlob=b64decode(envVar(env)),
            EncryptionContext={
                "LambdaFunctionName": envVar("AWS_LAMBDA_FUNCTION_NAME")
            },
        )["Plaintext"]
        .decode("utf-8")
    )


def random_string(length: int = 32) -> str:
    """

    Gets a random string

    >>> t1 = random_string()
    >>> t1.isalnum()
    True
    >>> len(t1) == 32
    True

    >>> t1 = random_string(10)
    >>> t1.isalnum()
    True
    >>> len(t1) == 10
    True

    """
    ASCII = string.ascii_letters
    return "".join(random.choice(ASCII) for i in range(length))
