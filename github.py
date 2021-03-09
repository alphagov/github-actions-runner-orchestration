import re
import requests


VALID_ORGS = ("alphagov", "cabinetoffice")


def checkGitHubToken(repo: str, token: str, commit_sha: str) -> bool:
    """

    Checks the commit is accessible from the token

    TODO

    """

    if not validRepo(repo):
        return False

    repo_regex = r"[A-Za-z0-9_. -]+/[A-Za-z0-9_. -]+"
    if not re.search(repo_regex, repo):
        return False

    alphanumeric_regex = r"[A-Za-z0-9]+"
    if not re.search(alphanumeric_regex, token):
        return False

    if not re.search(alphanumeric_regex, commit_sha):
        return False

    gh_uri = f"repos/{repo}/commits/{commit_sha}"
    url = f"https://api.github.com/{gh_uri}"

    headers = {
        "Accept": "application/vnd.github.v3+json",
        "Authorization": f"token {token}",
    }

    r = requests.get(url, headers=headers)

    if r.status_code == 200:
        j = r.json()
        if "sha" in j and j["sha"] == commit_sha:
            return True

    return False


def validRepo(repo: str) -> bool:
    """

    Checks if the repo is allowed to start runners

    >>> validRepo("")
    False

    >>> validRepo("OllieJC/test")
    False

    >>> validRepo("alphagov/test")
    True

    >>> validRepo("cabinetoffice/test")
    True

    >>> validRepo("trick_cabinetoffice/test")
    False

    >>> validRepo("cabinetofficetrick/test")
    False

    TODO

    """
    if repo:
        org = repo.split("/")[0]
        if org in VALID_ORGS:
            return True
    return False
