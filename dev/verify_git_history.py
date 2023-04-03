import re
import subprocess
import sys


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


########################################################################################################################

# Read the command line arguments and validate them

if len(sys.argv) != 3:
    print("Usage: %s <git-repo> <start-branch>" % sys.argv[0])
    exit(1)

repo = sys.argv[1]
start_branch = sys.argv[2]
main_branches = get_apache_branches(repo)

# check if start_branch is a valid branch
if start_branch not in main_branches:
    print("Invalid branch %s, must be one of %s" % (start_branch, str(main_branches)))
    exit(1)

# get items from main_branches starting from the item matching start_branch
main_branches = main_branches[main_branches.index(start_branch):]

# get the patch commit message
history = get_local_branch_history(repo, main_branches[0])

# history for the first branch must contain onlu one commit
if len(history) != 1:
    print("Invalid history for branch %s, must contain only one commit, but found %d: \n\n%s" % (
    main_branches[0], len(history), "\n".join(str(x) for x in history)))
    exit(1)

# check if the commit message is valid, that is, it must not be a merge commit
if parse_merge_commit_msg(history[0][1]):
    print("Invalid commit message for branch %s, must not be a merge commit, but found: \n\n%s" % (
    main_branches[0], history[0]))
    exit(1)

# Check the history of the branches to confirm that each branch contains exactly one main commit
# and the rest are the merge commits from the previous branch in order
expected_merges = []
prev_branch = main_branches[0]
prev_history = history
for branch in main_branches[1:]:
    expected_merges.append((prev_branch, branch))
    history = get_local_branch_history(repo, branch)

    if history[:-1] != prev_history:
        print("Invalid history for branch %s, must be the same as branch %s, but found: \n\n%s" % (
        branch, prev_branch, "\n".join(str(x) for x in history)))
        exit(1)

# expect that the rest of the commits are merge commits matching the expected merges in the same order
for i in range(1, len(history)):
    merge = parse_merge_commit_msg(history[i][1])
    if not merge:
        print("Invalid commit message for branch %s, must be a merge commit, but found: \n%s" % (branch, history[i]))
        exit(1)
    if merge != expected_merges[i - 1]:
        print(
            "Invalid merge commit for branch %s, expected: %s, but found: %s" % (branch, expected_merges[i - 1], merge))
        exit(1)

push_ranges = parse_push_ranges(repo, main_branches)
# number of push ranges must match the number of branches we want to merge
if len(push_ranges) != len(main_branches):
    print("Invalid number of push ranges, expected %d, but found %d:\n%s" % (
        len(main_branches), len(push_ranges), "\n".join(str(x) for x in push_ranges)))
    exit(1)

for push_range in push_ranges:
    print("-" * 80)
    print("Push range for branch %s: %s..%s" % (push_range[0], push_range[1], push_range[2]))
    print("git diff --name-only %s..%s" % (push_range[1], push_range[2]))
    print("git show %s..%s" % (push_range[1], push_range[2]))
    print("")
