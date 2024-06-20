import re
import subprocess
import sys
from typing import NamedTuple, Tuple

from lib.git_utils import *


class MergeSection(NamedTuple):
    version: Tuple[int, int]
    messages: list[str]


class ReleaseSection(NamedTuple):
    version: Tuple[int, int]
    version_string: str
    messages: list[str]
    merge_sections: list[MergeSection]


def read_changes_file(ticket: str) -> list[ReleaseSection]:
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
                if (ticket in lines[i]):
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
                f.write("Merged from %s:\n" % version_as_string(merge_section.version))
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
    print("Adds a change info to the CHANGES.txt file.")
    print("Usage: %s <ticket> <version_section> <list of merged from versions> <title>" % sys.argv[0])
    print("")
    print("Example: %s CASSANDRA-12345 '4.1' '3.11,4.0' 'Some awesome change'" % sys.argv[0])
    print("It adds a change info to the top of 'Merged from 3.11' section for the latest '4.1' section, ensuring that 'Merged from 4.0' is there as well.")
    exit(1)

ticket = sys.argv[1]
target_version_section_str = sys.argv[2]
target_merge_sections_strs = [s.strip() for s in sys.argv[3].split(",") if s.strip()]
title = sys.argv[4]

release_sections = read_changes_file(ticket)

if target_version_section_str == version_as_string(TRUNK_VERSION):
    # if the target version is trunk, we prepend the message to the first encountered version
    target_section = release_sections[0]
else:
    target_section = None
    for section in release_sections:
        if version_as_string(section.version) == target_version_section_str:
            target_section = section
            break

assert target_section, "Could not find target version section %s" % target_version_section_str

merge_section = None
for merge_section_str in target_merge_sections_strs:
    print("Looking for merge section %d" % len(target_merge_sections_strs))
    merge_section = get_or_insert_merge_section(target_section, version_from_string(merge_section_str))

new_message = " * %s (%s)\n" % (title, ticket)

if merge_section:
    merge_section.messages.insert(0, new_message)
else:
    target_section.messages.insert(0, new_message)

write_changes_file(release_sections)
