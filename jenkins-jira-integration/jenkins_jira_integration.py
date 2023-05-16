#!/usr/bin/python

import argparse
import json
import os
import re
import sys

from typing import Dict, Set
from jenkins import Jenkins
from jira import JIRA

import jenkins

# Used in logging method to flip logging on and off
VERBOSE = False

# Some helpers to tidy up object indexing
NO_PREVIOUS_BUILD = '-1'
NUMBER = 'number'
PREVIOUS_NUMBER = 'previous_number'
UNKNOWN = 'unknown'


def main() -> None:
    parser = argparse.ArgumentParser(description='Parse Jenkins build output and optionally update JIRA tickets with results for a single branch')
    parser._action_groups.pop()
    required = parser.add_argument_group('required arguments')
    optional = parser.add_argument_group('optional arguments')

    required.add_argument('--jenurl', type=str, help='Jenkins server url')
    required.add_argument('--jenuser', type=str, required=True, help='JIRA server url')
    required.add_argument('--jenpass', type=str, required=True, help='JIRA username')
    required.add_argument('--jiraurl', type=str, required=True, help='JIRA server url')
    required.add_argument('--jirauser', type=str, required=True, help='JIRA username')
    required.add_argument('--jirapass', type=str, required=True, help='JIRA password')
    required.add_argument('--branch', metavar='b', type=str, required=True,
                          help='Branch Versions to pull Jenkins results for')
    required.add_argument('--buildnum', metavar='n', type=str, help='Build number to process for CI status')

    optional.add_argument('--verbose', action='store_true', default='False', help='Verbose logging')
    optional.add_argument('--auto', action='store_true', default='False', help='Update Jira tickets with CI information automatically')

    args = parser.parse_args()
    global VERBOSE
    if args.verbose:
        VERBOSE = True

    # first we build the path to and confirm existence of the buildnum requested
    jenkins_url = 'https://ci-cassandra.apache.org'
    log('Connecting to jenkins server...')
    server = Jenkins(jenkins_url, username=args.jenuser, password=args.jenpass)

    # We store a per-branch JSON file with cached data of test number, previous number, and all failures so we don't
    # have to query JIRA for each build's data every time we run the script
    ci_cache = build_local_cache(server, args.branch, args.buildnum)

    log('Retrieving build. Branch: ' + args.branch + '. Build number: ' + args.buildnum)
    build_data = retrieve_build_details(server, args.branch, args.buildnum)

    # jira_results represents the data we're going to post to the final JIRA ticket about this CI run and test histories
    jira_results = '[CI Results]\n'
    jira_results += build_data.string_detailed()

    # Add a space between CI meta and test details for aesthetics
    jira_results += '\n'

    jira = JIRA('https://issues.apache.org/jira', basic_auth=(args.jirauser, args.jirapass))

    # Putting this in a table goes a long way towards making it parseable
    jira_results += '||Test|Failures|JIRA||\n'
    for test_name in build_data.test_failures:
        failures, total, jiralink = get_test_failure_details(jira, test_name, ci_cache)
        jira_results += ('|' + test_name + '|' + str(failures) + ' of ' + str(total) + '|' + jiralink + '\n')

    # Next, we want to query JIRA for the cassandra ticket in question and see if we've given it an update yet on build status; protect against spamming
    post_results_to_jira(jira, build_data.JIRA, args.branch, args.auto, jira_results)


class BuildData:
    def __init__(self, server: jenkins, branch: str, build_num: str) -> None:
        """
        A lot of the guts of this are painfully parsed out of the nested data structures in the Python API of a Jenkins build
        For example, see the Python API link on the following build on trunk: https://ci-cassandra.apache.org/job/Cassandra-trunk/959/testReport/api/
        (note: you may need to replace 959 w/a more recent build as they fall off the history to see it)
        :param server: jenkins server to query; expected to already be authenticated and connected
        :param branch: str of the branch name to pull from
        :param build_num: str of the build number to query
        """
        self.branch = branch
        self.number = build_num

        self.paths = []
        # TODO: Determine if depth=5 is necessary or in any way meaningful in this API Query. If so, document why.
        build = server.get_build_info('Cassandra-' + branch, int(build_num), depth=5)

        # The data structure and nesting in here _seems_ like it's going to be brittle and bite us in the future.
        # Should be able to access whatever the latest format of the Python API linked above is in order to correct
        # drifts and changes in the data structures, assuming things aren't completely dropped.
        for change_set in build['changeSets']:
            for items in change_set['items']:
                self.sha = items['commitId']
                for path in items['affectedPaths']:
                    self.paths.append(path)
                raw_comment = items['comment']

                # cache this so if it doesn't match a C* JIRA we can let the user know details
                self.commit_msg = raw_comment

                # We need to catch anyone that left bound the ticket # instead of following the idiom
                matches = re.match(r'[\S\s^]*CASSANDRA-([0-9]+)', raw_comment)
                if matches is not None:
                    self.JIRA = matches.group(1)
                else:
                    # We don't need to say anything here about it; we let whomever asked about this deal with the consequences
                    self.JIRA = UNKNOWN

        self.url = build['url']

        previous_build = build['previousBuild']
        if previous_build is None:
            self.previous_number = NO_PREVIOUS_BUILD
        else:
            self.previous_number = previous_build[NUMBER]

        self.result = build['result']

        tests = server.get_build_test_report('Cassandra-' + branch, int(build_num), depth=5)

        self.passcount = 0
        self.failcount = 0
        self.test_failures: Set[str] = set()

        # If we had a bad build, it's possible we have no test run results and should just be done with it
        if not tests:
            return

        self.passcount = tests['passCount']
        self.failcount = tests['failCount']

        suites = tests['suites']
        for suite in suites:
            for case in suite['cases']:
                # We treat failures and regressions the same as we're going to rely on our history cache to provide per-test failure context
                if (case['status'] == 'FAILED') or case['status'] == 'REGRESSION':
                    self.test_failures.add(case['className'] + '.' + case['name'])

    def string_detailed(self) -> str:
        """
        Builds out detailed job runs for posting on JIRA. Whitespace is lost but it looks clean enough w/things left
        aligned excepting the affected paths as a bullet list.
        """
        result = ''
        result += 'Branch: ' + self.branch + ', build number: ' + str(self.number) + '\n'

        prefix = '' if self.branch == 'trunk' else 'Cassandra-'
        result += '   butler url: https://butler.cassandra.apache.org/#/ci/upstream/compare/Cassandra-' + self.branch + '/' + prefix + self.branch + '\n'

        result += '   jenkins url: ' + str(self.url) + '\n'
        result += '   JIRA: CASSANDRA-' + str(self.JIRA) + '\n'
        result += '   commit url: https://git-wip-us.apache.org/repos/asf?p=cassandra.git;a=commit;h=' + str(self.sha) + '\n'
        result += '   affected paths:' + '\n'
        for path in self.paths:
            result += '* ' + path + '\n'
        result += '\n   Build Result: ' + self.result + '\n'
        result += '   Passing Tests: ' + str(self.passcount) + '\n'
        result += '   Failing Tests: ' + str(self.failcount) + '\n'
        return result


def retrieve_build_details(server: jenkins, branch: str, build_num: int) -> BuildData:
    result = None
    found_build = False

    log('Retrieving requested build: ' + str(build_num) + '. Branch: ' + branch + '. build_num: ' + str(build_num))
    result = BuildData(server, branch, str(build_num))

    # Some commit messages aren't JIRA related (ninjas, deb release changes, etc)
    if result.JIRA == UNKNOWN:
        print('No related CASSANDRA-NNNNN Jira found for build: ' + str(result.number) + '. Commit Message: ' + result.commit_msg)
        print('Exiting processing; nothing to be done for this build if we can\'t determine the JIRA ticket it\'s associated with.')
        sys.exit(-1)

    log('Parsed JIRA number: ' + result.JIRA + ' for build: ' + str(result.number))
    assert result is not None
    return result


def post_results_to_jira(jira: JIRA, ticket_number: str, branch: str, post_to_jira: bool, ci_results: str) -> None:
    """
    :param jira: Connected and authenticated JIRA instance
    :param ticket_number: as named
    :param branch: CI branch this job was for
    :param post_to_jira: Whether we should actively update Jira with the comment or print it to local output
            for a manual run / debugging
    :param ci_results: str to post to jira ticket
    :return:
    """
    log('Attempting to connect to jira and get issue: CASSANDRA-' + ticket_number)
    issue = jira.issue('CASSANDRA-' + ticket_number)
    log('Checking comments on ' + str(issue))
    comments = issue.fields.comment.comments

    # There's a little nuance here. We have two motions we could potentially need to go through
    #   1) We don't have anything on this ticket for this branch by JenkinsBot, so we want to add
    #   2) We already have an entry on this ticket for this branch by JenkinsBot, so we want to update

    # TODO put the correct account name here
    my_name = 'JenkinsBot'

    # Walk the comments for any we authored with the branch name of what we're processing. If we find it, update it
    for comment in comments:
        if str(comment.author) == my_name:
            # We know we wrote it; now we need to determine if this comment was for the branch we're currently
            # processing to determine if we need to update it
            comment_text = jira.comment('CASSANDRA-' + ticket_number, comment)
            if 'Branch: ' + branch in comment_text.body:
                # This is an update
                if post_to_jira is True:
                    comment.update(body=ci_results)
                else:
                    print('[UPDATE] comment to manually post to Jira for CASSANDRA-' + ticket_number)
                    print(ci_results)
                return

    if post_to_jira is True:
        print('Posting to JIRA from the bot is not yet tested and enabled.')
        # issue.add_comment('CASSANDRA-' + ticket_number, ci_results)
        print('[ADD] the following comment to Jira for CASSANDRA-' + ticket_number)
        print(ci_results)
    else:
        print('[ADD] the following comment to Jira for CASSANDRA-' + ticket_number)
        print(ci_results)


def build_local_cache(server: jenkins, branch: str, buildnum: str) -> Dict:
    """
    For the input build back as far as we have history, we want to cache the following (k/v):
        NUMBER:             str number of this build
        PREVIOUS_NUMBER     str build number of the previous build to walk to when walking the cache
        failures:           set of test failures seen for this build (note: sets aren't serializable in JSON so we cast to list)

        We use the build number and previous number as strings since they're going to get case to that in the JSON
        ser/deser anyway, so best not to mix.
    :return: testnu->
    """
    if not os.path.isdir('cache'):
        os.mkdir('cache')

    cached_data = {}
    json_file = 'cache/' + branch
    if os.path.exists(json_file):
        with open(json_file, 'r', encoding='utf-8') as infile:
            cached_data = json.load(infile)
        for build in cached_data:
            log('Loaded build: [' + str(build) + '] from cache')

    while buildnum != NO_PREVIOUS_BUILD:
        log('Processing cache for build_number ' + buildnum + ' on branch [' + branch + ']')
        if buildnum in cached_data:
            build_data = cached_data[buildnum]
            log('   Already found data for ' + buildnum + ' cached locally. Continuing to ' + str(build_data[PREVIOUS_NUMBER]))
            buildnum = str(build_data[PREVIOUS_NUMBER])
        else:
            print('   Did not find build_number: ' + buildnum + ' in the json cache. Populating...')
            # Pull the data from the Jenkins server as we don't have it in our cache
            build_data = BuildData(server, branch, buildnum)

            # The data in our JSON cache is a pretty simple subset of what we have in BuildData for a full CI report
            newcache_data = {}
            newcache_data[NUMBER] = build_data.number
            newcache_data[PREVIOUS_NUMBER] = build_data.previous_number
            # Can't serialize sets to JSON
            newcache_data['failures'] = list(build_data.test_failures)

            log('   Got data for ' + str(newcache_data[NUMBER]) + '. Caching and setting previous build pointer to: ' + str(newcache_data[PREVIOUS_NUMBER]))
            if 'failures' in newcache_data:
                log('   build number: ' + str(newcache_data[NUMBER]) + ' with failure count: ' + str(len(newcache_data['failures'])))

            # JSON comes back out as a string; need to follow suit here so the cache is all the same data type
            cached_data[str(build_data.number)] = newcache_data

            # cast to str should be redundant but it's coming out as an int. Not worth arguing with it.
            buildnum = str(newcache_data[PREVIOUS_NUMBER])

    log('   Hit limit of builds. Saving JSON.')
    with open(json_file, 'w', encoding='utf-8') as outfile:
        log('Updating the cache with recently queried results')
        json.dump(cached_data, outfile)

    return cached_data


def get_test_failure_details(jira: JIRA, test_name: str, data: Dict) -> tuple[int, int, str]:
    """
    :param data: Dict representing JSON cached data
    :return: failures, total, test failure JIRA url if found, link to test board if not
    """
    fail_count = 0
    total = 0

    for build in data:
        build_data = data[build]
        total += 1
        if test_name in build_data['failures']:
            fail_count += 1

    # See if we have a ticket for this failure already; pull out last 2 tokens from the . delimited test FQN
    tokens = test_name.split('.')

    # Take the class name only; we're not looking for a perfect match, just something of a jumping off point
    class_name = tokens[-2]

    # And split out the first token if there are underscores... /sigh
    # https://jira.atlassian.com/browse/JRASERVER-31882
    ctokens = class_name.split('_')
    class_name = ctokens[0]
    if '[' in class_name:
        btokens = class_name.split('[')
        class_name = btokens[1]

    # If we have a runtime configured test name with braces in it, we search for the root test class name only since JQL
    # is not fond of braces
    query = 'project = CASSANDRA and resolution = unresolved and summary ~ "*' + class_name + '*"'
    log('About to query via the following JQL: ' + query)
    try:
        log('Running query: ' + str(query))
        has_jira = jira.search_issues(query)
        log('Result: ' + str(has_jira))
    except Exception as e:
        print('ERROR! Got an exception attempting to get Jira for test failure.')
        print('Query that raised the exception: ' + query)
        print('Exception received: ' + str(e))
        print('Aborting.')
        sys.exit(-1)

    result = ''
    # We have a few states here:
    #   1) Empty result; didn't find anything w/this name. Point to the test board w/link
    #   2) We have *too many* results, or > 1. Link to the JQL that queries that so someone can check it out
    #   3) We have a single ticket who's summary matches our failure name.
    if has_jira == []:
        result = '[No JIRA found|https://issues.apache.org/jira/secure/RapidBoard.jspa?rapidView=496&quickFilter=2252]'
    elif len(has_jira) > 2:
        # Clean up some of our most common culprits that show up in Jira queries
        query = query.replace(' ', '%20')
        query = query.replace('=', '%3D')
        query = query.replace('\\', '%5C')
        result = '[Multiple JIRAs found|https://issues.apache.org/jira/issues/?jql=' + query + ']'
    else:
        result = '[' + str(has_jira[0]) + '?|https://issues.apache.org/jira/browse/' + str(has_jira[0]) + ']|'

    return fail_count, total, result


def log(to_log: str) -> None:
    if VERBOSE:
        print(to_log)


main()
