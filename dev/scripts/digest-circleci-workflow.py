# https://app.circleci.com/pipelines/github/jacek-lewandowski/cassandra/1252/workflows/b10132a7-1b4f-44d0-8808-f19a3b5fde69/jobs/63797
# https://circleci.com/api/v2/project/gh/jacek-lewandowski/cassandra/63797/tests
# {
#   "items": [
#     {
#       "classname": "org.apache.cassandra.distributed.test.LegacyCASTest",
#       "name": "testRepairIncompletePropose-_jdk17",
#       "result": "success",
#       "message": "",
#       "run_time": 15.254,
#       "source": "unknown"
#     }
#    ,{
#       "classname": "org.apache.cassandra.distributed.test.NativeTransportEncryptionOptionsTest",
#       "name": "testEndpointVerificationEnabledIpNotInSAN-cassandra.testtag_IS_UNDEFINED",
#       "result": "failure",
#       "message": "junit.framework.AssertionFailedError: Forked Java VM exited abnormally. Please note the time in the report does not reflect the time until the VM exit.\n\tat jdk.internal.reflect.GeneratedMethodAccessor4.invoke(Unknown Source)\n\tat java.base/jdk.internal.reflect.DelegatingMethodAccessorImpl.invoke(DelegatingMethodAccessorImpl.java:43)\n\tat java.base/java.util.Vector.forEach(Vector.java:1365)\n\tat jdk.internal.reflect.GeneratedMethodAccessor4.invoke(Unknown Source)\n\tat java.base/jdk.internal.reflect.DelegatingMethodAccessorImpl.invoke(DelegatingMethodAccessorImpl.java:43)\n\tat jdk.internal.reflect.GeneratedMethodAccessor4.invoke(Unknown Source)\n\tat java.base/jdk.internal.reflect.DelegatingMethodAccessorImpl.invoke(DelegatingMethodAccessorImpl.java:43)\n\tat java.base/java.util.Vector.forEach(Vector.java:1365)\n\tat jdk.internal.reflect.GeneratedMethodAccessor4.invoke(Unknown Source)\n\tat java.base/jdk.internal.reflect.DelegatingMethodAccessorImpl.invoke(DelegatingMethodAccessorImpl.java:43)\n\tat java.base/jdk.internal.reflect.NativeMethodAccessorImpl.invoke0(Native Method)\n\tat java.base/jdk.internal.reflect.NativeMethodAccessorImpl.invoke(NativeMethodAccessorImpl.java:77)\n\tat java.base/jdk.internal.reflect.DelegatingMethodAccessorImpl.invoke(DelegatingMethodAccessorImpl.java:43)\n\tat java.base/java.util.Vector.forEach(Vector.java:1365)\n\tat java.base/jdk.internal.reflect.NativeMethodAccessorImpl.invoke0(Native Method)\n\tat java.base/jdk.internal.reflect.NativeMethodAccessorImpl.invoke(NativeMethodAccessorImpl.java:77)\n\tat java.base/jdk.internal.reflect.DelegatingMethodAccessorImpl.invoke(DelegatingMethodAccessorImpl.java:43)\n\tat org.apache.cassandra.anttasks.TestHelper.execute(TestHelper.java:53)\n\tat jdk.internal.reflect.GeneratedMethodAccessor4.invoke(Unknown Source)\n\tat java.base/jdk.internal.reflect.DelegatingMethodAccessorImpl.invoke(DelegatingMethodAccessorImpl.java:43)\n\tat java.base/java.util.Vector.forEach(Vector.java:1365)\n\tat jdk.internal.reflect.GeneratedMethodAccessor4.invoke(Unknown Source)\n\tat java.base/jdk.internal.reflect.DelegatingMethodAccessorImpl.invoke(DelegatingMethodAccessorImpl.java:43)\n\tat jdk.internal.reflect.GeneratedMethodAccessor4.invoke(Unknown Source)\n\tat java.base/jdk.internal.reflect.DelegatingMethodAccessorImpl.invoke(DelegatingMethodAccessorImpl.java:43)",
#       "run_time": 0.001,
#       "source": "unknown"
#     }
#   ]
# }
import csv

# So here is the plan:
# I have a link to the pipeline: https://app.circleci.com/pipelines/github/jacek-lewandowski/cassandra/1252
# The program goes through all the workflow jobs and list the failed tests along with the workflow, job, etc.
# Then:
# - separate failures into 3 groups:
# 1. flaky - if a test was repeated in mulitple jobs and failred in some of them
# 2. failure - if a test was repeated in multiple jobs and failed in all of them
# 3. suspected - if a test was not repeated

# Then for each failure list Jira tickets that mention the test name.

# Having that information, let the user decide what to do with each failure:
# - select a jira ticket
# - create a new ticket
# - do not associate with any ticket
# - report on the PR

# Eventually, the user can create the script which can perform the planned operations

from lib.circleci_utils import *

class TestFailure(NamedTuple):
    file: str
    classname: str
    name: str
    jobs_comp: str
    jobs_list: list

class TestFailureComparison(NamedTuple):
    file: str
    classname: str
    name: str
    feature_jobs: set
    base_jobs: set
    jobs_comp: str

if len(sys.argv) != 4 and len(sys.argv) != 6:
    print("Usage: %s <repo> <workflow_id> <output.csv>" % sys.argv[0])
    print("Usage: %s <feature repo> <feature workflow id > <base repo> <base workflow id> <output.csv>" % sys.argv[0])
    sys.exit(1)

if len(sys.argv) == 4:
    repo = sys.argv[1]
    workflow_id = sys.argv[2]
    output_file = sys.argv[3]
    failed_tests_dict = get_failed_tests(repo, workflow_id)
    failed_tests = []
    for file in failed_tests_dict:
        for classname in failed_tests_dict[file]:
            for name in failed_tests_dict[file][classname]:
                jobs = list(failed_tests_dict[file][classname][name])
                jobs.sort()
                failed_tests.append(TestFailure(file, classname, name, ",".join(failed_tests_dict[file][classname][name]), jobs))

    # sort failed tests by jobs, file, classname, name
    failed_tests.sort(key=lambda test: (test.jobs_comp, test.file, test.classname, test.name))

    # save failed_tests to csv file
    with open(output_file, 'w') as csvfile:
        writer = csv.writer(csvfile)
        writer.writerow(['file', 'classname', 'name', 'jobs'])
        for test in failed_tests:
            writer.writerow([test.file, test.classname, test.name, test.jobs_comp])

else:
    feature_repo = sys.argv[1]
    feature_workflow_id = sys.argv[2]
    base_repo = sys.argv[3]
    base_workflow_id = sys.argv[4]
    output_file = sys.argv[5]
    feature_failed_tests_dict = get_failed_tests(feature_repo, feature_workflow_id)
    base_failed_tests_dict = get_failed_tests(base_repo, base_workflow_id)

    failed_tests = []
    all_files = set(feature_failed_tests_dict.keys()).union(set(base_failed_tests_dict.keys()))
    for file in all_files:
        feature_classnames = feature_failed_tests_dict[file] if file in feature_failed_tests_dict else {}
        base_classnames = base_failed_tests_dict[file] if file in base_failed_tests_dict else {}
        all_classnames = set(feature_classnames.keys()).union(set(base_classnames.keys()))
        for classname in all_classnames:
            feature_names = feature_classnames[classname] if classname in feature_classnames else {}
            base_names = base_classnames[classname] if classname in base_classnames else {}
            all_names = set(feature_names.keys()).union(set(base_names.keys()))
            for name in all_names:
                feature_jobs = feature_names[name] if name in feature_names else set()
                base_jobs = base_names[name] if name in base_names else set()
                jobs_comp = list(feature_jobs.union(base_jobs))
                jobs_comp.sort()
                failed_tests.append(TestFailureComparison(file, classname, name, feature_jobs, base_jobs, ",".join(jobs_comp)))

    # sort failed tests by jobs, file, classname, name
    failed_tests.sort(key=lambda test: (test.jobs_comp, test.file, test.classname, test.name))

    # save failed_tests to csv file
    with open(output_file, 'w') as csvfile:
        writer = csv.writer(csvfile)
        writer.writerow(['file', 'classname', 'name', 'failed in feature only', 'failed in base only', 'failed in both'])
        for test in failed_tests:
            feature_only_jobs = list(test.feature_jobs.difference(test.base_jobs))
            feature_only_jobs.sort()
            base_only_jobs = list(test.base_jobs.difference(test.feature_jobs))
            base_only_jobs.sort()
            common_jobs = list(test.feature_jobs.intersection(test.base_jobs))
            common_jobs.sort()
            writer.writerow([test.file, test.classname, test.name, ",".join(feature_only_jobs), ",".join(base_only_jobs), ",".join(common_jobs)])
