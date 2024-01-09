import re
import subprocess
import sys
from typing import NamedTuple, Tuple, Optional


class VersionedBranch(NamedTuple):
    version: Tuple[int, int]
    version_string: str
    name: str

class Commit(NamedTuple):
    sha: str
    author: str
    email: str
    title: str
    body: str

class BranchMergeInfo(NamedTuple):
    release_branch: VersionedBranch
    feature_branch: Optional[VersionedBranch]
    commits: list[Commit]

class TicketMergeInfo(NamedTuple):
    ticket: str
    update_changes: bool
    upstream_repo: str
    feature_repo: str
    merges: list[BranchMergeInfo]
    keep_changes_in_circleci: bool
    commit_msg_file: str

NO_VERSION = (-1, -1)
TRUNK_VERSION = (255, 255)

CASSANRA_BRANCH_VERSION_RE = re.compile(r"cassandra-(\d+)\.(\d+)")
VERSION_RE = re.compile(r"(\d+)\.(\d+)")

def version_from_re(re, string):
    match = re.match(string)
    if match:
        return (int(match.group(1)), int(match.group(2)))
    return None


def version_from_branch(branch):
    return version_from_re(CASSANRA_BRANCH_VERSION_RE, branch)


def version_from_string(version_string):
    if version_string == "trunk":
        return TRUNK_VERSION
    return version_from_re(VERSION_RE, version_string)


def version_as_string(version):
    if version is None:
        return None
    if version == NO_VERSION:
        return None
    if version == TRUNK_VERSION:
        return "trunk"
    return "%s.%s" % version


### GIT functions ###
def guess_base_version(repo, remote_repo, branch):
    version = NO_VERSION

    merge_base = None
    for l in subprocess.check_output(["git", "log", "--decorate", "--simplify-by-decoration", "--oneline", "%s/%s" % (repo, branch)], text=True).split("\n"):
        if "(HEAD" not in l and "(%s/%s" % (repo, branch) not in l:
            merge_base = l.split(" ")[0]
            break

    matching_versions = []
    if merge_base:
        branch_regex = re.compile(r"\s*" + re.escape(remote_repo) + r"/((cassandra-(\d+)\.(\d+))|(trunk))$")
        for l in subprocess.check_output(["git", "branch", "-r", "--contains", merge_base], text=True).split("\n"):
            match = branch_regex.match(l)
            if match:
                if match.group(5):
                    matching_versions.append(TRUNK_VERSION)
                elif match.group(2):
                    matching_versions.append((int(match.group(3)), int(match.group(4))))
        matching_versions.sort()

    if len(matching_versions) == 1:
        version = matching_versions[0]
    else:
        branch_regex = re.compile(r".*?([-/]((\d+)\.(\d+))|(trunk))?$", flags=re.IGNORECASE)
        match = branch_regex.match(branch)
        if match:
            if match.group(5) == "trunk":
                version = TRUNK_VERSION
            elif match.group(2):
                version = (int(match.group(3)), int(match.group(4)))
        else:
            print("No match for %s" % branch)
            if len(matching_versions) > 0:
                version = matching_versions[0]

    return version


def guess_feature_branches(repo, remote_repo, ticket):
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
            version = guess_base_version(repo, remote_repo, branch)
            matching_branches.append(VersionedBranch(version, match.group(2), branch))

    matching_branches.sort(key=lambda x: x.version)
    return matching_branches


def guess_feature_repo_and_ticket():
    """
    Get the remote repository and ticket number from the current git branch.
    :return: a tuple (remote_repository, ticket_number) or None if the current branch does not look like a feature branch
    """
    output = subprocess.check_output(["git", "status", "-b", "--porcelain=v2"], shell=False).decode("utf-8")
    regex = re.compile(r"# branch\.upstream ([^/]+)/([^ ]+)")
    match = regex.search(output)
    if match:
        ticket_regex = re.compile(r"CASSANDRA-(\d+)", flags=re.IGNORECASE)
        ticket_match = ticket_regex.search(match.group(2))
        if ticket_match:
            return (match.group(1), int(ticket_match.group(1)))
        return (match.group(1), None)
    return (None, None)


def guess_upstream_repo():
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
    :return: list of VersionedBranch objects
    """
    output = subprocess.check_output(["git", "ls-remote", "--refs", "-h", "-q", repo], text=True)
    branch_regex = re.compile(r".*refs/heads/(cassandra-((\d+)\.(\d+)))$")

    branches = []
    for line in output.split("\n"):
        match = branch_regex.match(line)
        if match:
            branches.append(VersionedBranch((int(match.group(3)), int(match.group(4))), match.group(2), match.group(1)))

    branches.append(VersionedBranch(TRUNK_VERSION, "", "trunk"))
    branches.sort(key=lambda x: x.version)

    return branches


def get_commits(from_repo, from_branch, to_repo, to_branch):
    """
    Get the commit history between two branches, sorted by commit date ascending.
    :param from_repo: start repository name or None for local branch
    :param from_branch: start branch name
    :param to_repo: end repository name or None for local branch
    :param to_branch: end branch name
    :return: a list of Commit objects
    """
    def coordinates(repo, branch):
        if repo:
            return "%s/%s" % (repo, branch)
        else:
            return branch
    output = subprocess.check_output(["git", "log", "--pretty=format:%h%n%aN%n%ae%n%s%n%b%n%x00", "--reverse", "%s..%s" % (coordinates(from_repo, from_branch), coordinates(to_repo, to_branch))], text=True)
    commits = []
    for commit_block in output.split("\0"):
        if not commit_block:
            continue
        match = commit_block.strip("\n").split(sep = "\n", maxsplit = 4)
        commits.append(Commit(match[0], match[1], match[2], match[3], match[4] if len(match) > 4 else ""))
    return commits


def parse_merge_commit_msg(msg):
    """
    Parse a merge commit message and return the source and destination branches.
    :param msg: a commit message
    :return: a tuple of (source_branch, destination_branch) or None if the message is not a merge commit
    """
    msg_regex = re.compile(r"Merge branch '(cassandra-\d+\.\d+)' into ((cassandra-(\d+\.\d+))|trunk)")
    match = msg_regex.match(msg)
    if match:
        return (match.group(1), match.group(2))
    return None


def ensure_clean_git_tree():
    output = subprocess.check_output(["git", "status", "--porcelain"], text=True)
    if output.strip():
        print("Your git tree is not clean. Please commit or stash your changes before running this script.")
        sys.exit(1)


def get_push_ranges(repo, branches):
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


def check_remote_exists(remote):
    try:
        return subprocess.check_call(["git", "remote", "get-url", remote], stderr=sys.stderr, stdout=None) == 0
    except subprocess.CalledProcessError:
        return False


def check_remote_branch_exists(remote, branch):
    return subprocess.check_call(["git", "ls-remote", "--exit-code", remote, branch], stderr=sys.stderr, stdout=None) == 0


### User input functions ###


def read_with_default(prompt, default):
    if default:
        value = input("%s [default: %s]: " % (prompt, default))
    else:
        value = input("%s: " % prompt)
    if not value:
        value = default
    return value


def read_remote_repository(prompt, default):
    repo = None

    while not repo:
        repo = read_with_default(prompt, default)
        if not check_remote_exists(repo):
            repo = None

    return repo


def read_positive_int(prompt, default):
    value = None
    while not value:
        try:
            if default:
                value = input("%s [default: %s]: " % (prompt, default))
            else:
                value = input(prompt)
            if value:
                v = int(value)
                if v > 0:
                    return v
            else:
                return default
        except ValueError:
            print("Invalid integer value")
            value = None
    return value

# from https://gist.github.com/rene-d/9e584a7dd2935d0f461904b9f2950007
class Colors:
    """ ANSI color codes """
    BLACK = "\033[0;30m"
    RED = "\033[0;31m"
    GREEN = "\033[0;32m"
    BROWN = "\033[0;33m"
    BLUE = "\033[0;34m"
    PURPLE = "\033[0;35m"
    CYAN = "\033[0;36m"
    LIGHT_GRAY = "\033[0;37m"
    DARK_GRAY = "\033[1;30m"
    LIGHT_RED = "\033[1;31m"
    LIGHT_GREEN = "\033[1;32m"
    YELLOW = "\033[1;33m"
    LIGHT_BLUE = "\033[1;34m"
    LIGHT_PURPLE = "\033[1;35m"
    LIGHT_CYAN = "\033[1;36m"
    LIGHT_WHITE = "\033[1;37m"
    BOLD = "\033[1m"
    FAINT = "\033[2m"
    ITALIC = "\033[3m"
    UNDERLINE = "\033[4m"
    BLINK = "\033[5m"
    NEGATIVE = "\033[7m"
    CROSSED = "\033[9m"
    END = "\033[0m"
