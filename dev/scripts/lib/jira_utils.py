import json

import urllib3


def get_assignee_from_jira(ticket):
    """
    Get the assignee for the given JIRA ticket.
    :param ticket:
    :return:
    """
    http = urllib3.PoolManager()
    r = http.request('GET', 'https://issues.apache.org/jira/rest/api/latest/issue/' + ticket)
    if r.status == 200:
        data = json.loads(r.data.decode('utf-8'))
        if data['fields']['assignee']:
            return data['fields']['assignee']['displayName']
    return None


def get_reviewers_from_jira(ticket):
    """
    Get the reviewers for the given JIRA ticket.
    :param ticket:
    :return:
    """
    http = urllib3.PoolManager()
    r = http.request('GET', 'https://issues.apache.org/jira/rest/api/latest/issue/' + ticket)
    if r.status == 200:
        data = json.loads(r.data.decode('utf-8'))
        reviewers = data['fields']['customfield_12313420']
        if reviewers:
            return [reviewer['displayName'] for reviewer in reviewers]
    return None
