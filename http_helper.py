import hmac
import hashlib
import base64
import json
import re
import time


def extractAndValidateBody(
    body: str,
    key: str = "",
    signature: str = "",
    isBase64: bool = False,
    with_validate: bool = True,
) -> dict:
    """
    Basic parsing of the body, including optional validation of a HMAC, to a dict

    >>> t = int(time.time())
    >>> valid_body = f"subnet=123&sg=456&repo=789&time={t}"
    >>> valid_b64b = base64.b64encode(valid_body.encode("utf-8")).decode("utf-8")

    >>> test1 = extractAndValidateBody(valid_b64b, isBase64=True, with_validate=False)
    >>> test1.pop("time") != "0"
    True
    >>> test1
    {'subnet': '123', 'sg': '456', 'repo': '789'}

    >>> test2 = extractAndValidateBody(valid_body, with_validate=False)
    >>> test2.pop("time") != "0"
    True
    >>> test2
    {'subnet': '123', 'sg': '456', 'repo': '789'}

    >>> kinda_valid = f"subnet= 123&sg= 456& repo=789 &time ={t}"
    >>> test3 = extractAndValidateBody(kinda_valid, with_validate=False)
    >>> test3.pop("time") != "0"
    True
    >>> test3
    {'subnet': '123', 'sg': '456', 'repo': '789'}

    >>> with open('tests/fixtures/example.json') as json_file:
    ...   example = json.load(json_file)
    >>> example["body"] = example["body"].replace("111", str(t))
    >>> test4 = extractAndValidateBody(example["body"], with_validate=False)
    >>> test4.pop("time") != "0"
    True
    >>> test4
    {'subnet': '123', 'sg': '456', 'repo': '789'}

    >>> try:
    ...     extractAndValidateBody(key="12345", body="sig=1234")
    ... except Exception as e:
    ...     print(e)
    key or signature missing

    >>> try:
    ...     extractAndValidateBody("subnet=123&sg=456&repo=789&time=1015213801", with_validate=False)
    ... except Exception as e:
    ...     print(e)
    request expired

    """

    if with_validate and (not key or not signature):
        raise Exception("key or signature missing")

    if isBase64:
        dec_body = base64.b64decode(body.encode("utf-8"))
        body = dec_body.decode("utf-8")

    body_qs = {
        x.split("=")[0].strip(): x.split("=")[1].strip() for x in body.split("&")
    }

    if not all(x in body_qs for x in ["time"]):
        raise Exception("missing required body item")

    requestTime = int(body_qs["time"])
    # less than 30 seconds old
    if (int(time.time()) - requestTime) >= 30:
        raise Exception(f"request expired")

    if with_validate:

        key_bytes = None

        if not key:
            raise Exception("Key not valid")
        else:
            key_bytes = key.encode("utf-8")

        h = hmac.new(key_bytes, body.encode("utf-8"), hashlib.sha512)
        res = h.hexdigest()

        if res == sig:
            return body_qs
        else:
            raise Exception("Bad signature")

    return body_qs
