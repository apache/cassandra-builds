import sys

from git_utils import get_local_branch_history, get_apache_branches, parse_merge_commit_msg, parse_push_ranges

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

# finally we print the commands to explore the changes in each push range

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
