import re
import subprocess


def get_apache_branches(repo):
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
            branches_with_versions.append((int(match.group(2)), int(match.group(3)), match.group(1)))

    branches_with_versions.sort()
    main_branches = [branch[2] for branch in branches_with_versions]
    main_branches.append("trunk")
    return main_branches


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
