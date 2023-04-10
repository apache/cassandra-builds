from lib.git_utils import *

# The script does two things:
# 1. Check that the history of the main branches (trunk, 4.0, 4.1, etc) is valid.
#    The history of the oldest branch must contain only one commit, and that commit must not be a merge commit.
#    The history of each newer branch must contain the history of the previous branch and a merge commit from that
#    previous branch.
# 2. Execute dry run of the push command and parse the results. Then, generate diff and show commands for the user
#    to manually inspect the changes.

# Example usage:
# python3 dev/scripts/verify_git_history.py apache cassandra-4.0,cassandra-4.1,trunk
#
# The script will check the history of local cassandra-4.0, cassandra-4.1 and trunk branches against their remote
# counterparts in the apache repository.

# Read the command line arguments and validate them
if len(sys.argv) != 3:
    print("Usage: %s <upstream-repo-name> <comma-separated-branches-to-push>" % sys.argv[0])
    exit(1)

repo = sys.argv[1]
main_branches = [s.strip() for s in sys.argv[2].split(",") if s.strip()]

if len(main_branches) == 0:
    print("No branches specified")
    exit(1)

# get the patch commit message
history = get_commits(repo, main_branches[0], None, main_branches[0])

print("")
print("Checking branch %s" % main_branches[0])
print("Expected merges: []")
print("History: \n - -%s" % "\n - ".join(str(x) for x in history))

# history for the first branch must contain only one commit
if len(history) != 1:
    print("Invalid history for branch %s, must contain only one commit, but found %d: \n\n%s" % (
    main_branches[0], len(history), "\n".join(str(x) for x in history)))
    exit(1)

# check if the commit message is valid, that is, it must not be a merge commit
if parse_merge_commit_msg(history[0].title):
    print("Invalid commit message for branch %s, must not be a merge commit, but found: \n\n%s" % (
    main_branches[0], history[0].title))
    exit(1)

# Check the history of the branches to confirm that each branch contains exactly one main commit
# and the rest are the merge commits from the previous branch in order
expected_merges = []
prev_branch = main_branches[0]
prev_history = history
for branch in main_branches[1:]:
    expected_merges.append((prev_branch, branch))
    history = get_commits(repo, branch, None, branch)

    print("")
    print("Checking branch %s" % branch)
    print("Expected merges: %s" % str(expected_merges))
    print("History: \n - %s" % "\n - ".join(str(x) for x in history))

    if history[:-1] != prev_history:
        print("Invalid history for branch %s, must include the history of branch %s:\n\n%s\n\n, but found: \n\n%s" % (
        branch, prev_branch,
        "\n".join(str(x) for x in prev_history),
        "\n".join(str(x) for x in history)))
        exit(1)

    # expect that the rest of the commits are merge commits matching the expected merges in the same order
    for i in range(1, len(history)):
        merge = parse_merge_commit_msg(history[i].title)
        if not merge:
            print("Invalid commit message for branch %s, must be a merge commit, but found: \n%s" % (branch, history[i]))
            exit(1)
        if merge != expected_merges[i - 1]:
            print(
                "Invalid merge commit for branch %s, expected: %s, but found: %s" % (branch, expected_merges[i - 1], merge))
            exit(1)

    prev_branch = branch
    prev_history = history

# finally we print the commands to explore the changes in each push range

push_ranges = get_push_ranges(repo, main_branches)
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
