import os
import tempfile

from lib.script_generator import generate_script
from lib.git_utils import *
from lib.jira_utils import *

ensure_clean_git_tree()

### Read feature repo, upstream repo and ticket
print("Remote repositories:")
print("")
subprocess.check_call(["git", "remote", "show"])
print("")

upstream_repo = read_remote_repository("Enter the name of the remote repository that points to the upstream Apache Cassandra", guess_upstream_repo())

feature_repo, ticket_number = guess_feature_repo_and_ticket()
feature_repo = read_remote_repository("Enter the name of the remote repository that points to the upstream feature branch", feature_repo)

ticket_number = read_positive_int("Enter the ticket number (for example: '12345'): ", ticket_number)
ticket = "CASSANDRA-%s" % ticket_number

print("")
print("Fetching from %s" % upstream_repo)
subprocess.check_output(["git", "fetch", upstream_repo])
if feature_repo != upstream_repo:
    print("Fetching from %s" % feature_repo)
    subprocess.check_output(["git", "fetch", feature_repo])


### Get the list of release branches and feature branches ###

release_branches = get_release_branches(upstream_repo)
if len(release_branches) == 0:
    print("No release branches found in %s" % upstream_repo)
    sys.exit(1)
print("Found the following release branches:\n%s" % "\n".join(["%s: %s" % (version_as_string(b.version), b.name) for b in release_branches]))
print("")

feature_branches = guess_feature_branches(feature_repo, upstream_repo, ticket)
print("Found the following feature branches:\n%s" % "\n".join(["%s: %s" % (version_as_string(b.version), b.name) for b in feature_branches]))
print("")

### Read the oldest release version the feature applies to ###

guessed_oldest_feature_version = feature_branches[0].version if len(feature_branches) > 0 else None
oldest_release_version = None
while not oldest_release_version:
    oldest_release_version_str = read_with_default("Enter the oldest release version to merge into", version_as_string(guessed_oldest_feature_version))
    if oldest_release_version_str:
        oldest_release_version = version_from_string(oldest_release_version_str)
        if oldest_release_version not in [b.version for b in release_branches]:
            print("Invalid release version: %s" % str(oldest_release_version))
            oldest_release_version = None

### Read the feature branches corresponding to each release branch ###

target_release_branches = [b for b in release_branches if b.version >= oldest_release_version]
merges = []
for release_branch in target_release_branches:
    # find first feature branch whose version is the same as the version of the release branch
    guessed_matching_feature_branch = next((b for b in feature_branches if b.version == release_branch.version), None)
    guessed_matching_feature_branch_name = guessed_matching_feature_branch.name if guessed_matching_feature_branch else "none"
    merge = None
    while merge is None:
        matching_feature_branch_name = read_with_default("Enter the name of the feature branch to merge into %s or type 'none' if there is no feature branch for this release" % release_branch.name, guessed_matching_feature_branch_name)
        if matching_feature_branch_name == "none":
            if len(merges) == 0:
                print("Feature branch for the oldest release must be provided")
                continue
            merge = BranchMergeInfo(release_branch, None, [])
        else:
            if matching_feature_branch_name in [b.name for b in feature_branches] or check_remote_branch_exists(feature_repo, matching_feature_branch_name):
                merge = BranchMergeInfo(release_branch, VersionedBranch(release_branch.version, NO_VERSION, matching_feature_branch_name), get_commits(upstream_repo, release_branch.name, feature_repo, matching_feature_branch_name))
            else:
                print("Invalid feature branch name: %s" % matching_feature_branch_name)
    merges.append(merge)


### Read the change title ###

need_changes_txt_entry = False
response = None
while response not in ["yes", "no"]:
    response = read_with_default("Do you want the script to add a line to CHANGES.txt? (yes/no)", "yes")
if response == "yes":
    update_changes = True
else:
    update_changes = False

### Keep the circleci config changes? ###
keep_changes_in_circleci = False
response = None
while response not in ["yes", "no"]:
    response = read_with_default("Do you want to keep changes in .circleci directory? (yes/no)", "no")
if response == "yes":
    keep_changes_in_circleci = True

### Generate commit message ###
commit_msg = merges[0].commits[0].title + "\n\n"
commit_msg = commit_msg + merges[0].commits[0].body + "\n\n"
for commit in merges[0].commits[1:]:
    commit_msg = commit_msg + " - " + commit.title + "\n" + commit.body + "\n\n"

assignee = get_assignee_from_jira(ticket)
reviewers = get_reviewers_from_jira(ticket)
if assignee:
    commit_msg = commit_msg + "Patch by %s" % assignee
if reviewers:
    commit_msg = commit_msg + "; reviewed by %s" % ", ".join(reviewers)
commit_msg = commit_msg + " for %s" % ticket

temp_dir = tempfile.gettempdir()
commit_msg_file = tempfile.NamedTemporaryFile(dir=temp_dir, delete=False)
commit_msg_file.write(commit_msg.encode('utf-8'))

print("")
print("Commit message saved to %s - you will be asked to edit" % commit_msg_file.name)

### Generate the script ###

ticket_merge_info = TicketMergeInfo(ticket, update_changes, upstream_repo, feature_repo, merges, keep_changes_in_circleci, commit_msg_file.name)

script = generate_script(ticket_merge_info)

# Read the filename to save the script to from either the command line or from the user
if len(sys.argv) > 1:
    filename = sys.argv[1]
else:
    filename = read_with_default("Enter the filename to save the script to", "../merge_%s.sh" % ticket)

# Save the script to the file
with open(filename, "w") as f:
    for s in script:
        f.write(s + "\n")

# make the script executable
os.chmod(filename, 0o755)
