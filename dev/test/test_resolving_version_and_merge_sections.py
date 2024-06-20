import unittest

from lib.script_generator import *


class MyTestCase(unittest.TestCase):
    v_50 = VersionedBranch((5, 0), "5.0", "trunk")
    v_41 = VersionedBranch((4, 1), "4.1", "cassandra-4.1")
    v_40 = VersionedBranch((4, 0), "4.0", "cassandra-4.0")
    v_311 = VersionedBranch((3, 11), "3.11", "cassandra-3.11")
    v_30 = VersionedBranch((3, 0), "3.0", "cassandra-3.0")

    # If the change is only for trunk, then:
    #  - we add the entry in the trunk section (top section).
    def test_trunk(self):
        merges = [(self.v_50, True)]
        version_section, merge_sections = resolve_version_and_merge_sections(0, merges)
        self.assertEqual(version_section, self.v_50)
        self.assertEqual(merge_sections, [])

    # If the change is for 4.1 and trunk, then:
    #  - in 4.1, we add the entry in the 4.1 section (top section)
    #  - in trunk, we add the entry in the 4.1 section (first encountered 4.1 section)
    def test_41_trunk(self):
        merges = [(self.v_41, True), (self.v_50, True)]
        version_section, merge_sections = resolve_version_and_merge_sections(0, merges)
        self.assertEqual(version_section, self.v_41)
        self.assertEqual(merge_sections, [])

        version_section, merge_sections = resolve_version_and_merge_sections(1, merges)
        self.assertEqual(version_section, self.v_41)
        self.assertEqual(merge_sections, [])

    # If the change is for 4.0, 4.1 and trunk, then:
    #  - in 4.0, we add the entry in the 4.0 section (top section)
    #  - in 4.1, we add then entry in the 4.1 section (top section), under "Merged from 4.0" subsection
    #  - in trunk, we add the entry in the 4.1 section (first encountered 4.1 section), under "Merged from 4.0" subsection
    def test_40_41_trunk(self):
        merges = [(self.v_40, True), (self.v_41, True), (self.v_50, True)]
        version_section, merge_sections = resolve_version_and_merge_sections(0, merges)
        self.assertEqual(version_section, self.v_40)
        self.assertEqual(merge_sections, [])

        version_section, merge_sections = resolve_version_and_merge_sections(1, merges)
        self.assertEqual(version_section, self.v_41)
        self.assertEqual(merge_sections, [self.v_40])

        version_section, merge_sections = resolve_version_and_merge_sections(2, merges)
        self.assertEqual(version_section, self.v_41)
        self.assertEqual(merge_sections, [self.v_40])

    # If the change is for 4.0 and not for 4.1 or trunk, then:
    #  - in 4.0, we add the entry in the 4.0 section (top section)
    #  - in 4.1, no changes
    #  - in trunk, no changes
    def test_40(self):
        merges = [(self.v_40, True), (self.v_41, False), (self.v_50, False)]
        version_section, merge_sections = resolve_version_and_merge_sections(0, merges)
        self.assertEqual(version_section, self.v_40)
        self.assertEqual(merge_sections, [])

        version_section, merge_sections = resolve_version_and_merge_sections(1, merges)
        self.assertEqual(version_section, None)
        self.assertEqual(merge_sections, [])

        version_section, merge_sections = resolve_version_and_merge_sections(2, merges)
        self.assertEqual(version_section, None)
        self.assertEqual(merge_sections, [])

    # If the change is for 3.11 and 4.1 and not for 4.0 or trunk, then:
    #  - in 3.11, we add the entry in the 3.11 section (top section)
    #  - in 4.0, no changes
    #  - in 4.1, we add the entry in the 4.1 section (top section), under "Merged from 3.11" subsection
    #  - in trunk, we add the entry in the 4.1 section (first encountered 4.1 section), under "Merged from 3.11" subsection
    def test_311_41(self):
        merges = [(self.v_311, True), (self.v_40, False), (self.v_41, True), (self.v_50, False)]
        version_section, merge_sections = resolve_version_and_merge_sections(0, merges)
        self.assertEqual(version_section, self.v_311)
        self.assertEqual(merge_sections, [])

        version_section, merge_sections = resolve_version_and_merge_sections(1, merges)
        self.assertEqual(version_section, None)
        self.assertEqual(merge_sections, [])

        version_section, merge_sections = resolve_version_and_merge_sections(2, merges)
        self.assertEqual(version_section, self.v_41)
        self.assertEqual(merge_sections, [self.v_40, self.v_311])

        version_section, merge_sections = resolve_version_and_merge_sections(3, merges)
        self.assertEqual(version_section, self.v_41)
        self.assertEqual(merge_sections, [self.v_40, self.v_311])

    # If the change is for 4.0 and trunk, and not for 4.1, then:
    #  - in 4.0, we add the entry in the 4.0 section (top section)
    #  - in 4.1, no changes
    #  - in trunk, no changes
    def test_40_trunk(self):
        merges = [(self.v_40, True), (self.v_41, False), (self.v_50, True)]
        version_section, merge_sections = resolve_version_and_merge_sections(0, merges)
        self.assertEqual(version_section, self.v_40)
        self.assertEqual(merge_sections, [])

        version_section, merge_sections = resolve_version_and_merge_sections(1, merges)
        self.assertEqual(version_section, None)
        self.assertEqual(merge_sections, [])

        version_section, merge_sections = resolve_version_and_merge_sections(2, merges)
        self.assertEqual(version_section, None)
        self.assertEqual(merge_sections, [])

    # If the change is for 3.0, 3.11, 4.0, 4.1 and trunk, then:
    #  - in 3.0, we add the entry in the 3.0 section (top section)
    #  - in 3.11, we add the entry in the 3.11 section (top section), under "Merged from 3.0" subsection
    #  - in 4.0, we add the entry in the 4.0 section (top section), under "Merged from 3.0" subsection
    #  - in 4.1, we add the entry in the 4.1 section (top section), under "Merged from 3.0" subsection
    #  - in trunk, we add the entry in the 4.1 section (first encountered 4.1 section), under "Merged from 3.0" subsection
    def test_30_311_40_41_trunk(self):
        merges = [(self.v_30, True), (self.v_311, True), (self.v_40, True), (self.v_41, True), (self.v_50, True)]
        version_section, merge_sections = resolve_version_and_merge_sections(0, merges)
        self.assertEqual(version_section, self.v_30)
        self.assertEqual(merge_sections, [])

        version_section, merge_sections = resolve_version_and_merge_sections(1, merges)
        self.assertEqual(version_section, self.v_311)
        self.assertEqual(merge_sections, [self.v_30])

        version_section, merge_sections = resolve_version_and_merge_sections(2, merges)
        self.assertEqual(version_section, self.v_40)
        self.assertEqual(merge_sections, [self.v_311, self.v_30])

        version_section, merge_sections = resolve_version_and_merge_sections(3, merges)
        self.assertEqual(version_section, self.v_41)
        self.assertEqual(merge_sections, [self.v_40, self.v_311, self.v_30])

        version_section, merge_sections = resolve_version_and_merge_sections(4, merges)
        self.assertEqual(version_section, self.v_41)
        self.assertEqual(merge_sections, [self.v_40, self.v_311, self.v_30])


if __name__ == '__main__':
    unittest.main()
