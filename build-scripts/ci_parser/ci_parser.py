#!/usr/bin/env python3

"""
Script to take an arbitrary root directory of subdirectories of junit output format and create a summary .html file
with their results.
"""

import argparse
import cProfile
import pstats
import os
import shutil
import tarfile
import xml.etree.ElementTree as ET
from concurrent.futures import ThreadPoolExecutor, as_completed
from typing import Callable, Dict, List, IO, Optional, Tuple, Type
from pathlib import Path

from junit_helpers import JUnitResultBuilder, JUnitTestCase, JUnitTestSuite, JUnitTestStatus, LOG_FILE_NAME
from logging_helper import build_logger, mute_logging, CustomLogger

try:
    from bs4 import BeautifulSoup
except ImportError:
    print('bs4 not installed; make sure you have bs4 in your active python env.')
    exit(1)


parser = argparse.ArgumentParser(description="""
Parses ci results provided ci output in input path and generates html
results in specified output file. Expects an existing .html file to insert
results into; this file will be backed up into a <file_name>.bak file in its
local directory.
""")
parser.add_argument('--input', type=str, help='path to input files (recursive directory search for *.xml)')
# TODO: Change this paradigm to a full "input dir translates into output file", where output file includes some uuid
# We'll need full support for all job types, not just junit, which will also necessitate refactoring into some kind of
# TestResultParser, of which JUnit would be one type. But there's a clear pattern here we can extract. Thinking checkstyle.
parser.add_argument('--output', type=str, help='existing .html output file to append to')
parser.add_argument('--mute', action='store_true', help='mutes stdout and only logs to log file')
parser.add_argument('--profile', '-p', action='store_true', help='Enable perf profiling on operations')
parser.add_argument('-v', '-d', '--verbose', '--debug', dest='debug', action='store_true', help='verbose log output')
args = parser.parse_args()
if args.input is None or args.output is None:
    parser.print_help()
    exit(1)

logger = build_logger(LOG_FILE_NAME, args.debug)  # type: CustomLogger
if args.mute:
    mute_logging(logger)


def main():
    check_file_condition(lambda: os.path.exists(args.input), f'Cannot find {args.input}. Aborting.')
    check_file_condition(lambda: os.path.exists(args.output), 'This mode is designed to insert a table into an existing .html file. Cannot proceed.')
    test_suites = extract_junit_from_test_run(args.input)
    for suite in test_suites.values():
        logger.info(f'Suite: {suite.name()}')
        logger.info(f'-- Passed: {suite.passed()}')
        logger.info(f'-- Failure: {suite.failed()}')
        logger.info(f'-- Skipped: {suite.skipped()}')
        if suite.is_empty() and suite.file_count() == 0:
            logger.warning(f'Have an empty test_suite: {suite.name()} that had no .xml files associated with it. Did the jobs run correctly and produce junit files? Check {suite.get_archive()} for test run command result details.')
        elif suite.is_empty():
            logger.warning(f'Got an unexpected empty test_suite: {suite.name()} with no .xml file parsing associated with it. Check {LOG_FILE_NAME}.log when run with -v for details.')
    append_failure_results(test_suites, args.output)


def extract_junit_from_test_run(input_dir: str) -> Dict[str, JUnitTestSuite]:
    """
    For a given input input_dir, will find all .gz files in that tree, extract files from them preserving input_dir structure
    and parse out all found junit test results into the global test result containers.
    :param input_dir: Input directory to recursively search for .gz files
    """

    # Skip archives that we know exist but don't have results we want.
    gz_exclusions = ['split', 'result_details']

    # Inclusions win over exclusions right now but are empty by default.

    # TODO: Make this a command-line regex? Used for debugging; could use to parse just a certain subset of suites.
    gz_inclusions = None  # type: Optional[List[str]]
    # gz_inclusions = ['python']

    # TODO: Make this a command-line debug flag? Used for debugging
    debug_file = None  # type: Optional[str]
    # debug_file = 'jvm17-utests_archive.tar.gz'
    if debug_file is not None:
        gz_files = [str(file) for file in Path(input_dir).rglob('*.gz') if debug_file in str(file)]
    elif gz_inclusions is not None:
        gz_files = [str(file) for file in Path(input_dir).rglob('*.gz') if any(x in str(file) for x in gz_inclusions)]
    else:
        gz_files = [str(file) for file in Path(input_dir).rglob('*.gz') if not any(x in str(file) for x in gz_exclusions)]
    check_file_condition(lambda: len(gz_files) != 0, f'Found 0 .gz files in path: {input_dir}. Cannot proceed with .xml extraction.')
    logger.debug(f'Extracting .xml from {len(gz_files)} gzip files from path: {input_dir}')

    archive_count = 0
    test_file_count = 0
    test_count = 0

    test_suites = dict()  # type: Dict[str, JUnitTestSuite]

    logger.info('List of gzip files to be processed:')
    for file in gz_files:
        logger.info(f' -- {file}')

    # Since we have a 1:1 ratio on .gz files to suites, we can parallelize w/out any kind of synchronization. We also
    # check to ensure this contract is upheld in the processing method.
    with ThreadPoolExecutor() as executor:
        futures = [executor.submit(process_gzip_file, gz_file, input_dir, test_suites) for gz_file in gz_files]
        for future in as_completed(futures):
            exception = future.exception()
            if exception is not None:
                logger.critical('Saw an exception processing .gzip file. Aborting.')
                raise exception
            else:
                files, tests = future.result()
                test_file_count += files
                test_count += tests

    logger.progress(f'Total archive count: {archive_count}')
    logger.progress(f'Total junit file count: {test_file_count}')
    logger.progress(f'Total suite count: {len(test_suites.keys())}')
    logger.progress(f'Total test count: {test_count}')
    passed = 0
    failed = 0
    skipped = 0

    for suite in test_suites.values():
        passed += suite.passed()
        failed += suite.failed()
        if suite.failed() != 0:
            print_errors(suite)
        skipped += suite.skipped()

    logger.progress(f'-- Passed: {passed}')
    logger.progress(f'-- Failed: {failed}')
    logger.progress(f'-- Skipped: {skipped}')
    return test_suites


def process_gzip_file(gz_file: str, input_dir: str, test_suites: Dict[str, JUnitTestSuite]) -> Tuple[int, int]:
    """
    Pretty straightforward here - we unpack all our .gz files, walk through any .xml files in there and look for tests,
    parsing them out into our global JUnitTestCase Dicts as we find them

    No thread safety on target Dict -> relying on the "one .gz per suite" rule to keep things clean

    This takes place in the context of an executor thread
    :return: Tuple[file count, test count]
    """
    # Leading part of non-root portion of path needs to correlate to job / pipeline name. We'll group by those.
    logger.debug(f'Replacing input_dir: {input_dir} in path: {gz_file}.')
    suite_name = gz_file.replace(input_dir, '').lstrip('/').split('/')[0]
    logger.progress(f'Processing archive: {gz_file} for test suite: {suite_name}')

    # And make sure we're not racing
    if suite_name in test_suites:
        log_and_raise(f'Got a duplicate suite_name - this will lead to race conditions. Suite: {suite_name}. gz file: {gz_file}. Aborting', AssertionError)
    else:
        test_suites[suite_name] = JUnitTestSuite(suite_name)

    active_suite = test_suites[suite_name]
    # Store this for later logging if we have a failed job; help the user know where to look next.
    active_suite.set_archive(gz_file)
    active_file = ''
    test_file_count = 0
    test_count = 0
    try:
        with tarfile.open(gz_file, 'r:gz') as tar:
            # Since we can theoretically have duplicate members of .xml files modified at different times, we build up a
            # list of whatever the latest sequential member of any .xml file is and then use that.
            for member in tar.getmembers():
                if '.xml' in member.name:
                    file_name = member.name.split('/')[-1]
                    active_file = file_name
                    fc = extract_test_cases(active_suite, file_name, tar.extractfile(member))
                    if fc != 0:
                        test_file_count += 1
                        test_count += fc
    except EOFError:
        logger.error(f'EOFError on {gz_file}. Skipping; will be missing results for {suite_name}')
        return 0, 0
    except Exception as e:
        logger.critical(f'Got unexpected error while parsing {gz_file} on file: {active_file}: {e}. Aborting.')
        raise e
    return test_file_count, test_count


def print_errors(suite: JUnitTestSuite) -> None:
    logger.warning(f'\n[Printing {suite.failed()} tests from suite: {suite.name()}]')
    for testcase in suite.get_tests(JUnitTestStatus.FAILURE):
        logger.warning(f'{testcase}')


def extract_test_cases(suite: JUnitTestSuite, file_name: str, file_contents: Optional[IO[bytes]]) -> int:
    """
    For a given input .xml, will extract all JUnitTestCase matching objects and store them in the global registry keyed off
    suite name.

    Called in context of executor thread.
    :param suite: The JUnitTestSuite object we're currently working with
    :param file_name: .xml file_name to check for tests. May or may not be junit format.
    :param file_contents: uncompressed file contents to read .xml from
    :return : count of tests extracted from this file_name
    """
    xml_exclusions = ['logback', 'checkstyle']
    if any(x in file_name for x in xml_exclusions):
        return 0

    # TODO: In extreme cases (python upgrade dtests), this could theoretically be a HUGE file we're materializing in memory. Consider .iterparse or tag sanitization using sed first.
    root = ET.parse(file_contents).getroot()  # type: ignore

    # Search inside entire hierarchy since sometimes it's at the root and sometimes one level down.
    test_count = len(root.findall('.//testcase'))
    if test_count == 0:
        logger.warning(f'Appear to be processing an .xml file without any junit tests in it: {file_name}. Update .xml exclusions to exclude this.')
        if args.debug:
            logger.info(ET.tostring(root))
        return 0

    suite.add_file(file_name)
    found = 0
    for testcase in root.iter('testcase'):
        processed = JUnitTestCase(testcase)
        suite.add_testcase(processed)
        found = 1
    if found == 0:
        logger.error(f'file: {file_name} has test_count: {test_count} but root.iter iterated across nothing!')
        logger.error(ET.tostring(root))
    return test_count


# TODO: Update this to instead be "create_summary_file" and build the entire summary page, not just append failures to existing
# This should be trivial to do using JUnitTestSuite.failed, passed, etc methods
def append_failure_results(test_suites: Dict[str, JUnitTestSuite], output: str) -> None:
    """
    Will create a table with all failed tests in it organized by sorted suite name.
    :param test_suites: Collection of JUnitTestSuite's parsed out pass/fail data
    :param output: Path to the .html we want to append to the <body> of
    """
    with open(output, 'r') as file:
        soup = BeautifulSoup(file, 'html.parser')

    new_tag = soup.new_tag("div", style="font-size: 22px; color: white; font-weight: bold;")
    new_tag.string = '[Test Failure Details]'
    soup.body.append(new_tag)
    JUnitResultBuilder.add_style_tags(soup)

    # We cut off at 200 failures; if you have > than that chances are you have a bad run and there's no point in
    # just continuing to pollute the summary file with it and blow past file size. Since the inlined failures are
    # a tool to be used in the attaching / review process and not primarily workflow and fixing.
    total_failure_count = 0
    for suite_name in sorted(test_suites.keys()):
        suite = test_suites[suite_name]
        failure_count = suite.count(JUnitTestStatus.FAILURE)
        if failure_count == 0:
            # Don't append anything to results in the happy path case.
            logger.debug(f'No failed tests in suite: {suite_name}')
        else:
            # Else independent table per suite.
            builder = JUnitResultBuilder(suite_name, failure_count)
            builder.label_columns(JUnitTestCase.headers())
            for test in suite.get_tests(JUnitTestStatus.FAILURE):
                builder.add_row(test.row_data())
            table_data = BeautifulSoup(builder.build_table(), 'html.parser')
            soup.append(table_data)
        total_failure_count += failure_count
        # TODO: Consider making 200 configurable via a command-line flag if we find this is useful for local debugging work.
        if total_failure_count > 200:
            logger.critical(f'Saw {total_failure_count} failures; greater than 200 threshold. Not appending further failure details to {output}.')
            break

    # Only backup the output file if we've gotten this far
    shutil.copyfile(output, output + '.bak')

    # We write w/formatter set to None as invalid char above our insertion in the input file we're modifying (from other
    # tests, test output, etc) can cause the parser to get very confused and do Bad Things.
    with open(output, 'w') as file:
        file.write(soup.prettify(formatter=None))
    logger.progress(f'Test failure details appended to file: {output}')


def check_file_condition(function: Callable[[], bool], msg: str) -> None:
    """
    Specifically raises a FileNotFoundError if something's wrong with the Callable
    """
    if not function():
        log_and_raise(msg, FileNotFoundError)


def log_and_raise(msg: str, error_type: Type[BaseException]) -> None:
    logger.critical(msg)
    raise error_type(msg)


if __name__ == "__main__" and args.profile:
    profiler = cProfile.Profile()
    profiler.enable()
    main()
    profiler.disable()
    stats = pstats.Stats(profiler).sort_stats('cumulative')
    stats.print_stats()
else:
    main()
