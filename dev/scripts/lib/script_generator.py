import os

from lib.git_utils import *

def resolve_version_and_merge_sections(idx: int, merges: list[Tuple[VersionedBranch, bool]]) -> Tuple[Optional[VersionedBranch], list[VersionedBranch]]:
    """
    Compute the version and merge sections for a given index in the CHANGES.txt file.
    See the unit tests for examples.

    :param idx: the index of the merge
    :param merges: list of merges
    :return: the version and merge sections
    """

    version_section = None
    merge_sections = []
    release_branch, is_patch_defined = merges[idx]

    assert idx > 0 or is_patch_defined, "The first merge must be a patch"

    if idx == 0:  # which means that we are in the oldest version
        # in this case we just add the title for the version
        version_section = release_branch
        # no merge section in this case

    elif idx == (len(merges) - 1): # which means that this is a merge for trunk
        # in this case version section is either len(merges) - 2 or None
        before_last_release_branch, is_patch_defined_for_before_last = merges[idx - 1]
        if is_patch_defined_for_before_last:
            # version section is defined only if the before last release branch is a patch
            version_section = before_last_release_branch
            for i in range(idx - 2, -1, -1):
                release_branch, _ = merges[i]
                merge_sections.append(release_branch)

    elif is_patch_defined:
        # otherwise, version section is defined only if there is a patch for the release branch
        version_section = release_branch
        for i in range(idx - 1, -1, -1):
            release_branch, _ = merges[i]
            merge_sections.append(release_branch)

    return version_section, merge_sections

def generate_script(ticket_merge_info: TicketMergeInfo):
    assert ticket_merge_info.merges[0].feature_branch is not None

    script_dir = os.path.dirname(os.path.dirname(os.path.realpath(__file__)))

    script = ["#!/bin/bash", "", "set -xe", "", "[[ -z $(git status --porcelain) ]] # worktree must be clean"]

    merges = ticket_merge_info.merges
    # index of first merge with undefined feature branch
    for idx in range(0, len(merges)):
        merge = merges[idx]
        script.append("")
        script.append("")
        script.append("")
        if merge.feature_branch is not None:
            script.append("# Commands for merging %s -> %s" % (merge.feature_branch.name, merge.release_branch.name))
        else:
            script.append("# Commands for skipping -> %s" % merge.release_branch.name)
        script.append("#" * 80)

        if merge.feature_branch:
            # ensure that there is at least one non-merge commit in the feature branch
            assert len([c for c in merge.commits if parse_merge_commit_msg(c.title) is None]) > 0

        script.append("git switch %s" % merge.release_branch.name)
        script.append("git reset --hard %s/%s" % (ticket_merge_info.upstream_repo, merge.release_branch.name))
        commits = []
        if idx == 0:
            # oldest version
            script.append("git cherry-pick %s # %s - %s" % (
            merge.commits[0].sha, merge.commits[0].author, merge.commits[0].title))
            commits = merge.commits[1:]
        else:
            script.append("git merge -s ours --log --no-edit %s" % merges[idx - 1].release_branch.name)
            commits = merge.commits

        for commit in commits:
            merge_msg = parse_merge_commit_msg(commit.title)
            if merge_msg:
                script.append("# skipping merge commit %s %s - %s" % (commit.sha, commit.author, commit.title))
            else:
                script.append("git cherry-pick -n %s # %s - %s" % (commit.sha, commit.author, commit.title))

        version_section, merge_sections = resolve_version_and_merge_sections(idx, [(m.release_branch, m.feature_branch is not None) for m in merges])
        if ticket_merge_info.title and version_section:
            script.append("python3 %s/update_changes.py '%s' '%s' '%s' '%s'" % (script_dir,
                                                                                ticket_merge_info.ticket,
                                                                                version_as_string(version_section.version),
                                                                                ",".join([version_as_string(m.version) for m in merge_sections]),
                                                                                ticket_merge_info.title))

            script.append("git add CHANGES.txt")
            script.append("git commit --amend --no-edit")

        if not ticket_merge_info.keep_changes_in_circleci:
            script.append("[[ -n \"$(git diff --name-only %s/%s..HEAD -- .circleci/)\" ]] && (git diff %s/%s..HEAD -- .circleci/ | git apply -R --index) && git commit -a --amend --no-edit # Remove all changes in .circleci directory if you need to" % (ticket_merge_info.upstream_repo, merge.release_branch.name, ticket_merge_info.upstream_repo, merge.release_branch.name))
        script.append("git diff --name-only %s/%s..HEAD # print a list of all changes files" % (ticket_merge_info.upstream_repo, merge.release_branch.name))

    script.append("")
    script.append("")
    script.append("")
    script.append("# After executing the above commands, please run the following verification, and manually inspect the results of the commands it generates")
    script.append("python3 %s/verify_git_history.py '%s' '%s'" % (script_dir, ticket_merge_info.upstream_repo, ",".join([m.release_branch.name for m in merges])))

    return script
