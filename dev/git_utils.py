import re
import subprocess
import sys
from typing import NamedTuple, Tuple

class FeatureBranch(NamedTuple):
    version: Tuple[int, int]
    version_string: str
    name: str

NO_VERSION = (-1, -1)
TRUNK = (255, 255)

def get_feature_branches(repo, ticket):
    """
    Get the list of branches from the given repository that contain the given ticket, sorted by version ascending.
    :param repo: configured apache repository name
    :param ticket: ticket number
    :return: list of branch names
    """
    output = subprocess.check_output(["git", "ls-remote", "--refs", "-h", "-q", repo], text=True)
    branch_regex = re.compile(r".*refs/heads/(" + re.escape(ticket) + r"(-(\d+)\.(\d+))?.*)$", flags=re.IGNORECASE)
    print(r".*refs/heads/(" + re.escape(ticket) + r"((\d+)\.(\d+))?.*)$")
    matching_branches = []
    for line in output.split("\n"):
        match = branch_regex.match(line)
        if match:
            branch = match.group(1)
            if branch == ticket:
                version = TRUNK
            elif match.group(2):
                version = (int(match.group(3)), int(match.group(4)))
            else:
                version = NO_VERSION
            matching_branches.append(FeatureBranch(version, match.group(2), branch))

    matching_branches.sort(key=lambda x: x.version)
    return matching_branches

def get_upstream_branch_and_repo():
    """
    Get the upstream branch and repository name for the current branch.
    :return: a tuple of (remote_name, branch_name, ticket_number) or None if the current branch is not tracking a remote branch
    """
    output = subprocess.check_output(["git", "status", "-b", "--porcelain=v2"], shell=False).decode("utf-8")
    regex = re.compile(r"# branch\.upstream ([^/]+)/([^ ]+)")
    match = regex.search(output)
    if match:
        ticket_regex = re.compile(r"CASSANDRA-(\d+)", flags=re.IGNORECASE)
        ticket_match = ticket_regex.search(match.group(2))
        if ticket_match:
            return (match.group(1), match.group(2), ticket_match.group(1))
        return (match.group(1), match.group(2), None)
    return None


def get_remote_cassandra_repository_name():
    """
    Get the name of the remote repository that points to the apache cassandra repository. Prefers "apache" over "asf".
    :return: the remote name
    """
    output = subprocess.check_output(["git", "remote", "show"], shell=False)
    apache_remote_name = None
    for remote_name in output.decode("utf-8").split("\n"):
        url = subprocess.check_output(["git", "remote", "get-url", remote_name], shell=False).decode("utf-8").strip()
        if "apache/cassandra.git" in url:
            return remote_name
        if "asf/cassandra/git" in url:
            apache_remote_name = remote_name
    return apache_remote_name

def get_release_branches(repo):
    """
    Get the list of main cassandra branches from the given repo, sorted by version ascending.
    :param repo: configured apache repository name
    :return: list of branch names
    """
    output = subprocess.check_output(["git", "ls-remote", "--refs", "-h", "-q", repo], shell=False)
    branch_regex = re.compile(r".*refs/heads/(cassandra-(\d+)\.(\d+))$")

    branches_with_versions = []
    for line in output.decode("utf-8").split("\n"):
        match = branch_regex.match(line)
        if match:
            branches_with_versions.append(FeatureBranch((int(match.group(2)), int(match.group(3))), "-%s.%s" % (match.group(2), match.group(3)), match.group(1)))

    branches_with_versions.append(FeatureBranch(TRUNK, "", "trunk"))
    branches_with_versions.sort(key=lambda x: x.version)

    return branches_with_versions


def get_local_branch_history(repo, branch):
    """
    Get the commit history between local branch and remote branch, sorted by commit date ascending.
    :param repo: configured apache repository name
    :param branch: branch name
    :return: a list of tuples (commit_hash, commit_message)
    """
    output = subprocess.check_output(["git", "log", "--pretty=format:%H %s", "%s/%s..%s" % (repo, branch, branch)],
                                     shell=False)
    history = []
    line_regex = re.compile(r"([0-9a-f]+) (.*)")
    for line in output.decode("utf-8").split("\n"):
        match = line_regex.match(line)
        if match:
            history.append((match.group(1), match.group(2)))
    history.reverse()
    return history


def parse_merge_commit_msg(msg):
    """
    Parse a merge commit message and return the source and destination branches.
    :param msg: a commit message
    :return: a tuple of (source_branch, destination_branch) or None if the message is not a merge commit
    """
    msg_regex = re.compile(r"Merge branch '(cassandra-\d+\.\d+)' into (cassandra-((\d+\.\d+)|trunk))")
    match = msg_regex.match(msg)
    if match:
        return (match.group(1), match.group(2))
    return None


def parse_push_ranges(repo, branches):
    """
    Parse the output of git push --atomic -n and return a list of tuples (label, start_commit, end_commit)
    :param repo: configured apache repository name
    :param branches: list of branch names
    :return: list of tuples (label, start_commit, end_commit)
    """
    output = subprocess.check_output(["git", "push", "--atomic", "-n", "--porcelain", repo] + branches, shell=False)
    range_regex = re.compile(r"^\s+refs/heads/\S+:refs/heads/(\S+)\s+([0-9a-f]+)\.\.([0-9a-f]+)$")
    ranges = []
    for line in output.decode("utf-8").split("\n"):
        match = range_regex.match(line)
        if match:
            ranges.append((match.group(1), match.group(2), match.group(3)))
    return ranges

cassandra_branch_version_re = re.compile(r"cassandra-(\d+)\.(\d+)")
version_string_re = re.compile(r"(\d+)\.(\d+)")

def version_from_re(re, string):
    match = re.match(string)
    if match:
        return (int(match.group(1)), int(match.group(2)))
    return None

def version_from_branch(branch):
    return version_from_re(cassandra_branch_version_re, branch)

def version_from_string(version_string):
    return version_from_re(version_string_re, version_string)

def check_remote_exists(remote):
    return subprocess.check_call(["git", "remote", "get-url", remote], stderr=sys.stderr, stdout=None) == 0

def check_remote_branch_exists(remote, branch):
    return subprocess.check_call(["git", "ls-remote", "--exit-code", remote, branch], stderr=sys.stderr, stdout=None) == 0

def version_as_string(version):
    if version is None:
        return None
    if version == TRUNK:
        return "trunk"
    return "%s.%s" % version
