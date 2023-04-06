import subprocess
import sys
import re
from git_utils import *

def read_with_default(prompt, default):
    value = input("%s [default: %s]: " % (prompt, default))
    if not value:
        value = default
    return value

def read_remote_repository(prompt, default):
    print("Remote repositories:")
    subprocess.check_call(["git", "remote", "show"])
    print("")
    repo = None

    while not repo:
        repo = read_with_default(prompt, default)
        if not check_remote_exists(repo):
            print("Invalid remote repository name: %s" % repo)
            repo = None

    return repo


# read upstream repository name from stdin
upstream_repo = read_with_default("Enter the name of the remote repository that points to the upstream Apache Cassandra", get_remote_cassandra_repository_name())

feature_repo, feature_branch, ticket_number = get_upstream_branch_and_repo()
feature_repo = read_remote_repository("Enter the name of the remote repository that points to the upstream feature branch", feature_repo)

ticket_number = read_with_default("Enter the ticket number", ticket_number)
ticket = "CASSANDRA-%s" % ticket_number

print("")
print("Fetching from %s and %s" % (upstream_repo, feature_repo))
subprocess.check_output(["git", "fetch", upstream_repo])
if feature_repo != upstream_repo:
    subprocess.check_output(["git", "fetch", feature_repo])

release_branches = get_release_branches(upstream_repo)
if len(release_branches) == 0:
    print("No release branches found in %s" % upstream_repo)
    sys.exit(1)

print("Found the following release branches:\n%s" % "\n".join([str(b) for b in release_branches]))
print("")

feature_branches = get_feature_branches(feature_repo, ticket)
print("Found the following feature branches:\n%s" % "\n".join([str(x) for x in feature_branches]))
print("")

default_oldest_feature_version = feature_branches[0].version if len(feature_branches) > 0 else None
oldest_release_version = None
while not oldest_release_version:
    oldest_release_version = read_with_default("Enter the oldest release version to merge into", version_as_string(default_oldest_feature_version))
    if oldest_release_version:
        oldest_release_version = version_from_string(oldest_release_version)
        if oldest_release_version not in [b.version for b in release_branches]:
            print("Invalid release version: %s" % str(oldest_release_version))
            oldest_release_version = None

target_release_branches = [b for b in release_branches if b.version >= oldest_release_version]
merges = []
for release_branch in target_release_branches:
    # find first feature branch whose version is the same as the version of the release branch
    default_matching_feature_branch = next((b for b in feature_branches if b.version == release_branch.version), None)
    default_matching_feature_branch_name = default_matching_feature_branch.name if default_matching_feature_branch else "none"
    merge = None
    while merge is None:
        matching_feature_branch_name = read_with_default("Enter the name of the feature branch to merge into %s or type 'none' if there is no feature branch for this release" % release_branch.name, default_matching_feature_branch_name)
        if matching_feature_branch_name == "none":
            if len(merges) == 0:
                print("Feature branch for the oldest release must be provided")
                continue
            merge = (release_branch, None)
        else:
            if check_remote_branch_exists(feature_repo, matching_feature_branch_name):
                merge = (release_branch, matching_feature_branch_name)
            else:
                print("Invalid feature branch name: %s" % matching_feature_branch_name)
    merges.append(merge)

print("")
print("Merge commands:")
for release_branch, feature_branch in merges:
    if feature_branch:
        print("%s -> %s" % (feature_branch, release_branch.name))
    else:
        print("none -> %s" % release_branch.name)

# list commits of the oldest branch and let the user decide whose commit message should be used as a title in CHANGES.txt
print("")
print("Commits:")
commits = subprocess.check_output(["git", "log", "--reverse", "--pretty=format:%s", "%s/%s..%s/%s" % (upstream_repo, merges[0][0].name, feature_repo, merges[0][1])], text=True).splitlines()
# zip commits with their index
commits = list(zip(range(1, len(commits) + 1), commits))
for i, commit in commits:
    print("%d: %s" % (i, commit))
print("")
change_title = read_with_default("Enter the number of the commit whose message should be used as a title in CHANGES.txt or leave empty to enter a custom title", "")
if change_title:
    change_title = commits[int(change_title) - 1][1]
else:
    change_title = read_with_default("Enter the title", commits[0][1])

# then generate the script



