import json
import sys
from enum import Enum
from typing import NamedTuple

import urllib3

class PipelineInfo(NamedTuple):
    id: str
    number: int

def get_pipelines_from_circleci(repo, branch):
    http = urllib3.PoolManager()
    url = "https://circleci.com/api/v2/project/gh/%s/cassandra/pipeline?branch=%s" % (repo, branch)
    r = http.request('GET', url)
    if r.status == 200:
        items = json.loads(r.data.decode('utf-8'))['items']
        return [PipelineInfo(id=item['id'], number=item['number']) for item in items]
    return None

class WorkflowInfo(NamedTuple):
    id: str
    name: str
    status: str

def get_pipeline_workflows(pipeline_id):
    http = urllib3.PoolManager()
    url = "https://circleci.com/api/v2/pipeline/%s/workflow" % (pipeline_id)
    r = http.request('GET', url)
    if r.status == 200:
        items = json.loads(r.data.decode('utf-8'))['items']
        return [WorkflowInfo(id=item['id'], name=item['name'], status=item['status']) for item in items]

class JobType(Enum):
    BUILD = "build"
    APPROVAL = "approval"

class JobStatus(Enum):
    SUCCESS = "success"
    RUNNING = "running"
    NOT_RUN = "not_run"
    FAILED = "failed"
    RETRIED = "retried"
    QUEUED = "queued"
    NOT_RUNNING = "not_running"
    INFRASTRUCTURE_FAIL = "infrastructure_fail"
    TIMEDOUT = "timedout"
    ON_HOLD = "on_hold"
    TERMINATED_UNKNOWN = "terminated-unknown"
    BLOCKED = "blocked"
    CANCELED = "canceled"
    UNAUTHORIZED = "unauthorized"

class JobInfo(NamedTuple):
    id: str
    name: str
    status: JobStatus
    job_number: str
    type: JobType

def job_info_from_json(json):
    return JobInfo(id=json['id'], name=json['name'], status=JobStatus(json['status']), job_number=json['job_number'] if 'job_number' in json else None , type=JobType(json['type']))

def get_workflow_jobs(workflow_id):
    http = urllib3.PoolManager()
    url = "https://circleci.com/api/v2/workflow/%s/job" % (workflow_id)
    r = http.request('GET', url)
    if r.status == 200:
        items = json.loads(r.data.decode('utf-8'))['items']
        print("Found %d jobs" % len(items))
        return [job_info_from_json(item) for item in items]
    return None

def get_failed_jobs(workflow_id):
    jobs = get_workflow_jobs(workflow_id)
    failed_jobs = []
    for job in jobs:
        if job.status == JobStatus.FAILED and job.job_number is not None:
            failed_jobs.append(job)
        else:
            print("Skipping job %s" % str(job))
    return failed_jobs

class TestResult(Enum):
    SUCCESS = "success"
    FAILURE = "failure"
    SKIPPED = "skipped"
    ERROR = "error"
    UNKNOWN = "unknown"

class TestInfo(NamedTuple):
    message: str
    source: str
    run_time: float
    file: str
    result: TestResult
    name: str
    classname: str

def get_job_tests(repo, job_number):
    http = urllib3.PoolManager()
    url = "https://circleci.com/api/v2/project/gh/%s/cassandra/%s/tests" % (repo, job_number)
    r = http.request('GET', url)
    if r.status == 200:
        tests = [TestInfo(t['message'], t['source'], t['run_time'], t['file'] if 'file' in t else "", TestResult(t['result']), t['name'], t['classname']) for t in json.loads(r.data.decode('utf-8'))['items']]
        return tests
    return None


def get_failed_tests(repo, workflow_id):
    failed_jobs = get_failed_jobs(workflow_id)
    failed_tests = {}
    for job in failed_jobs:
        print("Getting tests for job %s" % str(job))
        tests = get_job_tests(repo, job.job_number)
        for test in tests:
            if test.result == TestResult.FAILURE:
                if test.file not in failed_tests:
                    failed_tests[test.file] = {}
                if test.classname not in failed_tests[test.file]:
                    failed_tests[test.file][test.classname] = {}
                test_name = test.name.split("-", 2)[0]
                test_name = test_name.split("[", 2)[0]
                if test_name not in failed_tests[test.file][test.classname]:
                    failed_tests[test.file][test.classname][test_name] = set()
                failed_tests[test.file][test.classname][test_name].add(job.name)

    return failed_tests
