import re
import subprocess
import sys
from typing import NamedTuple, Tuple

from git_utils import get_apache_branches, version_from_branch, version_from_string, version_from_re


class MergeSection(NamedTuple):
    version: Tuple[int, int]
    messages: list[str]


class ReleaseSection(NamedTuple):
    version: Tuple[int, int]
    version_string: str
    messages: list[str]
    merge_sections: list[MergeSection]


def read_changes_file() -> list[ReleaseSection]:
    """
    Read the changes file and return a list of release sections.
    :return: a list of release sections
    """
    merge_section_regex = re.compile(r"^Merged from (\d+)\.(\d+):")
    release_sections = []
    with open("CHANGES.txt", "r") as f:
        lines = f.readlines()

        messages = []
        merge_sections = []
        release_section = None
        merge_section = None

        # go through each line and record its index if it matches the pattern \d+\.\d+.*
        for i in range(len(lines)):
            version = version_from_string(lines[i])
            merge_version = version_from_re(merge_section_regex, lines[i])

            if version:
                if merge_section:
                    merge_sections.append(merge_section)

                if release_section:
                    release_sections.append(release_section)

                messages = []
                merge_sections = []
                merge_section = None
                release_section = ReleaseSection(version, lines[i], messages, merge_sections)

            elif merge_version:
                if merge_section:
                    merge_sections.append(merge_section)

                messages = []
                merge_section = MergeSection(merge_version, messages)

            elif lines[i].strip():
                if (ticket in lines[i] or message in lines[i]):
                    print("Found duplicate message in line %d: %s" % (i + 1, lines[i]))
                    exit(1)
                messages.append(lines[i])

        if release_section:
            release_sections.append(release_section)

    return release_sections


# write a text file with the changes
def write_changes_file(release_sections: list[ReleaseSection]):
    """
    Write the changes file.
    :param release_sections: the release sections to write
    """
    with open("CHANGES.txt", "w") as f:
        for version_section in release_sections:
            f.write(version_section.version_string)
            for message in version_section.messages:
                f.write(message)

            for merge_section in version_section.merge_sections:
                f.write("Merged from %d.%d:\n" % merge_section.version)
                for message in merge_section.messages:
                    f.write(message)

            f.write("\n\n")


def get_or_insert_merge_section(target_section: ReleaseSection, target_version: Tuple[int, int]) -> MergeSection:
    """
    Get the merge section for the given version in the given release section. If the merge section does not exist, it is
    created and inserted in the correct position.
    :param target_section: the release section to search for the merge section
    :param target_version: the version of the merge section to search for
    :return: found or created merge section
    """
    target_merge_section = None
    insertion_index = -1
    for idx in range(len(target_section.merge_sections)):
        insertion_index = idx + 1
        if target_section.merge_sections[idx].version == target_version:
            # merge section already exists, return it
            target_merge_section = target_section.merge_sections[idx]
            break
        elif target_section.merge_sections[idx].version < target_version:
            # merge section does not exist because we just reached the first merge section with a lower version
            insertion_index = idx - 1
            break

    if not target_merge_section:
        # merge section does not exist, create it and insert in the correct position
        target_merge_section = MergeSection(target_version, [])
        target_section.merge_sections.insert(insertion_index, target_merge_section)

    return target_merge_section


# check if the commond line args contain the message and a list of branches
if len(sys.argv) < 5:
    print("Usage: %s <repo> <version> <ticket> <message>" % sys.argv[0])
    exit(1)

repo = sys.argv[1]
target_branch = sys.argv[2]
target_version = version_from_string(target_branch)
ticket = sys.argv[3]
message = sys.argv[4]

release_sections = read_changes_file()

merge_versions = []
for branch in get_apache_branches(repo):
    if branch == "trunk":
        version = release_sections[0].version
    else:
        version = version_from_branch(branch)
    if version:
        merge_versions.append(version)

merge_versions = merge_versions[merge_versions.index(target_version):]
current_branch = subprocess.check_output(["git", "branch", "--show-current"], shell=False).decode("utf-8").strip()

target_section = None
target_merge_section = None
new_message = " * %s (%s)\n" % (message, ticket)

if current_branch == "trunk":
    current_version = release_sections[0].version
    if current_version == target_version:
        # if we are on trunk and the target version is also trunk, we prepend the message to the first encountered version
        target_section = release_sections[0]
    else:
        # if we are on trunk, but the target version is older, we prepend the message to the appropriate merge section
        # (which may be created if it does not exist) in the second encountered version
        target_section = release_sections[1]
        for merge_version in merge_versions[1:-1]:
            get_or_insert_merge_section(target_section, merge_version)
        target_merge_section = get_or_insert_merge_section(target_section, target_version)
else:
    current_version = version_from_branch(current_branch)
    merge_versions = merge_versions[:merge_versions.index(current_version)]
    target_section = release_sections[0]
    if current_version != target_version:
        for merge_version in merge_versions[1:-1]:
            get_or_insert_merge_section(target_section, merge_version)
        target_merge_section = get_or_insert_merge_section(target_section, target_version)

if target_merge_section:
    target_merge_section.messages.insert(0, new_message)
elif target_section:
    target_section.messages.insert(0, new_message)
else:
    print("Could not find target section")
    exit(1)

write_changes_file(release_sections)
