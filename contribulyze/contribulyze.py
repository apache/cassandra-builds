#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
#
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.
#
#

#
# See usage() for details, or run with --help option.
#
#  Copied and evolved from script of same name from Apache Subversion
#

import getopt
import json
import os
import re
import requests
import sys
from dateutil import parser
from urllib.parse import quote as urllib_parse_quote
try:
  my_getopt = getopt.gnu_getopt
except AttributeError:
  my_getopt = getopt.getopt


# Parsing and data stuff.
#
# Some Cassandra project log messages include parseable data to help
# track who's contributing what.
# Here's an example, indented by three spaces, i.e., the "patch by:"
# starts at the beginning of a line:
#
#    Reject token() in MV WHERE clause
#
#    Patch by Krishna Koneru and Damien Stevenson; review by Benjamin Lerer,
#    Brandon Williams and Zhao Yang for CASSANDRA-13464
#
#    Co-authored-by: Krishna Koneru <krishna.koneru@instaclustr.com>
#    Co-authored-by: Damien Stevenson <damien@localhost.damien>
#
#
# This is a pathological example, but it shows all the things we might
# need to parse.  We need to:
#
#   - Detect the normal "WORD by … (and …)" fields.
#   - Grab every name in each field.
#   - Handle names in various formats, unifying where possible.
#   - Handle newlines
#   - Handle trailing github `Co-authored-by: ` lines
#

class Contributor(object):
  # Map contributor names to contributor instances, so that there
  # exists exactly one instance associated with a given name.
  # Fold names with email addresses.  That is, if we see someone
  # listed first with just an email address, but later with a real
  # name and that same email address together, we create only one
  # instance, and store it under both the email and the real name.
  all_contributors = { }

  def __init__(self, name, email):
    """Instantiate a contributor.  Don't use this to generate a
    Contributor for an external caller, though, use .get() instead."""
    self.name = name
    self.aliases  = set()
    self.email     = email
    self.is_committer = False       # Assume not until hear otherwise.
    # Map verbs (e.g., "Patch", "Suggested", "Review") to lists of
    # LogMessage objects.  For example, the log messages stored under
    # "Patch" represent all the revisions for which this contributor
    # contributed a patch.
    self.activities = { }
    self.interactions = set()

  def add_aliases(self, alias):
      self.aliases.add(alias)
      Contributor.all_contributors[alias] = self
      Contributor.all_contributors[alias.lower()] = self
      
  def add_activity(self, field, log):
    """Record that this contributor was active in FIELD_NAME in LOG."""
    logs = self.activities.get(field.name)
    if not logs:
      logs = [ ]
      self.activities[field.name] = logs
    if not log in logs:
      logs.append(log)

  def add_collaboration(self, field):
    for c in field.contributors:
        if c != self:
            self.interactions.add(c)

  @staticmethod
  def get(name, email):
    """If this contributor is already registered, just return it;
    otherwise, register it then return it.  Hint: use parse() to
    generate the arguments."""
    c = None
    for key in name, email:
      if key and key in Contributor.all_contributors:
        c = Contributor.all_contributors[key]
        break
    # If we didn't get a Contributor, create one now.
    if not c:
      c = Contributor(name, email)
    # If we know identifying information that the Contributor lacks,
    # then give it to the Contributor now.
    if name:
      if not c.name:
        c.name = name
      Contributor.all_contributors[name]  = c
      Contributor.all_contributors[name.lower()]  = c
    if email:
      if not c.email:
        c.email = email
      Contributor.all_contributors[email]     = c
    # This Contributor has never been in better shape; return it.
    return c

  def score(self):
    """Return a contribution score for this contributor."""
    # Right now we count both patches and reviews as 1
    score = 0
    for activity in self.activities.keys():
      score += len(self.activities[activity])
    return score

  def score_str(self):
    """Return a contribution score HTML string for this contributor."""
    patch_score = 0
    other_score = 0
    for activity in self.activities.keys():
      if activity == 'Patch':
        patch_score += len(self.activities[activity])
      else:
        other_score += len(self.activities[activity])
    if patch_score == 0:
      patch_str = ""
    elif patch_score == 1:
      patch_str = "1&nbsp;patch"
    else:
      patch_str = "%d&nbsp;patches" % patch_score
    if other_score == 0:
      other_str = ""
    elif other_score == 1:
      other_str = "1&nbsp;review"
    else:
      other_str = "%d&nbsp;reviews" % other_score
    collaboraters_str = "%d&nbsp;collaborator" % (len(self.interactions))
    return ",&nbsp;".join((patch_str, other_str, collaboraters_str))

  def __cmp__(self, other):
    if self.is_committer and not other.is_committer:
      return 1
    if other.is_committer and not self.is_committer:
      return -1
    result = cmp(self.score(), other.score())
    if result == 0:
      return cmp(self.big_name(), other.big_name())
    else:
      return 0 - result

  def sort_key(self):
      return (self.is_committer, self.score(), self.big_name())

  @staticmethod
  def parse(name):
    """Parse NAME, which can be

       - A committer username, or
       - A space-separated real name, or
       - A space-separated real name followed by an email address in
           angle brackets, or
       - Just an email address in angle brackets.

     (The email address may have '@' disguised as '{_AT_}'.)

     Return a tuple of (committer_username, real_name, email_address)
     any of which can be None if not available in NAME."""
    name  = None
    email     = None
    name_components = name.split()
    if len(name_components) == 1:
      name = name_components[0] # Effectively, name = name.strip()
      if name[0] == '<' and name[-1] == '>':
        email = name[1:-1]
      elif name.find('@') != -1 or name.find('{_AT_}') != -1:
        email = name
      else:
        name = name
    elif name_components[-1][0] == '<' and name_components[-1][-1] == '>':
      email = name_components[-1][1:-1]

    if email is not None:
      # We unobfuscate here and work with the '@' internally, since
      # we'll obfuscate it again (differently) before writing it out.
      email = email.replace('{_AT_}', '@')

    return name, email

  def canonical_name(self):
    """Return a canonical name for this contributor.  The canonical
    name may or may not be based on the contributor's actual email
    address.

    The canonical name will not contain filename-unsafe characters.

    This method is guaranteed to return the same canonical name every
    time only if no further contributions are recorded from this
    contributor after the first call.  This is because a contribution
    may bring a new form of the contributor's name, one which affects
    the algorithm used to construct canonical names."""
    retval = None
    if self.name:
      retval = self.name
    elif self.email:
      # Take some rudimentary steps to shorten the email address, to
      # make it more manageable.  If this is ever discovered to result
      # in collisions, we can always just use to the full address.
      try:
        at_posn = self.email.index('@')
        first_dot_after_at = self.email.index('.', at_posn)
        retval = self.email[0:first_dot_after_at]
      except ValueError:
        retval = self.email
    if retval is None:
      complain('Unable to construct a canonical name for Contributor.', True)
    return urllib_parse_quote(retval, safe="!#$&'()+,;<=>@[]^`{}~")

  def big_name(self, html=False, html_eo=False):
    """Return as complete a name as possible for this contributor.
    If HTML, then call html_spam_guard() on email addresses.
    If HTML_EO, then do the same, but specifying entities_only mode."""
    html = html or html_eo
    name_bits = []
    if self.email:
      if not self.name:
        name_bits.append(self.email)
      elif html:
        name_bits.append("&lt;%s&gt;" % html_spam_guard(self.email, html_eo))
      else:
        name_bits.append("<%s>" % self.email)
    if self.name:
      if not self.email:
        name_bits.append(self.name)
      else:
        name_bits.append("(%s)" % self.name)
    return " ".join(name_bits)

  def __str__(self):
    s = 'CONTRIBUTOR: '
    s += self.big_name()
    s += "\ncanonical name: '%s'" % self.canonical_name()
    if len(self.activities) > 0:
      s += '\n   '
    for activity in self.activities.keys():
      val = self.activities[activity]
      s += '[%s:' % activity
      for log in val:
        s += ' %s' % log.revision
      s += ']'
    return s

  def html_out(self, filename, title):
    """Create an HTML file named FILENAME, showing all the revisions in which
    this contributor was active."""
    out = open(filename, 'w')
    out.write(html_header('%s %s' % (self.big_name(html_eo=True), title), '%s %s' % (self.big_name(html=True), title), True))

    sorted_interactions = sorted(self.interactions, key=Contributor.sort_key, reverse=True)
    out.write('<div class="h2" id="interactions" title="interactions">\n\n')
    out.write('<table border="1"><tr><td>&nbsp;%s Collaborator</td></tr>\n' % (len(sorted_interactions)))
    out.write('<tr>\n')
    out.write('<td>\n')
    first_activity = True
    for interaction in sorted_interactions:
        s = ' , '
        if first_activity:
          s = ''
          first_activity = False
        urlpath = "%s.html" % (interaction.canonical_name())
        out.write('%s<a href="%s">%s</a>' % (s, urllib_parse_quote(urlpath), interaction.name))

    out.write('</td>\n')
    out.write('</tr>\n')
    out.write('</table><br/>\n\n')

    unique_logs = { }

    sorted_activities = sorted(self.activities.keys())

    out.write('<div class="h2" id="activities" title="activities">\n\n')
    out.write('<table border="1">\n')
    out.write('<tr>\n')
    for activity in sorted_activities:
      out.write('<td>&nbsp;%s %s</td>\n\n' % (len(self.activities[activity]), activity))
    out.write('</tr>\n')
    out.write('<tr>\n')
    for activity in sorted_activities:
      out.write('<td>\n')
      first_activity = True
      for log in self.activities[activity]:
        s = ',\n'
        if first_activity:
          s = ''
          first_activity = False
        out.write('%s<a href="#%s">%s</a>' % (s, log.sha, log.sha))
        unique_logs[log] = True
      out.write('</td>\n')
    out.write('</tr>\n')
    out.write('</table>\n\n')
    out.write('</div>\n\n')

    sorted_logs = sorted(unique_logs.keys(), key=LogMessage.sort_key, reverse=True)
    for log in sorted_logs:
      out.write('<hr />\n')
      out.write('<div class="h3" id="%s" title="%s">\n' % (log.sha, log.sha))
      out.write('<pre>\n')
      sha = '<a href="https://github.com/apache/cassandra/commit/%s">%s</a>' % (log.sha, log.sha)
      out.write('<b>%s | %s | %s</b>\n\n' % (sha, escape_html(log.author), log.date))
      out.write(spam_guard_in_html_block(re.sub(r'for CASSANDRA-([0-9]+)', r'for <a href="https://issues.apache.org/jira/browse/CASSANDRA-\1">CASSANDRA-\1</a>', escape_html(log.message))))
      out.write('</pre>\n')
      out.write('</div>\n\n')
    out.write('<hr />\n')

    out.write(html_footer())
    out.close()

class Field:
  """One field in one log message."""
  def __init__(self, name, alias = None):
    # The name of this field (e.g., "Patch", "Review", etc).
    self.name = name
    # An alias for the name of this field (e.g., "Reviewed").
    self.alias = alias
    # A list of contributor objects, in the order in which they were
    # encountered in the field.
    self.contributors = set()
    # Any parenthesized asides immediately following the field.  The
    # parentheses and trailing newline are left on.  In theory, this
    # supports concatenation of consecutive asides.  In practice, the
    # parser only detects the first one anyway, because additional
    # ones are very uncommon and furthermore by that point one should
    # probably be looking at the full log message.
    self.addendum = ''
  def add_contributor(self, contributor):
    self.contributors.add(contributor)
  def add_endum(self, addendum):
    self.addendum += addendum
  def __str__(self):
    s = 'FIELD: %s (%d contributors)\n' % (self.name, len(self.contributors))
    for contributor in self.contributors:
      s += str(contributor) + '\n'
    s += self.addendum
    return s


class LogMessage(object):
  # Maps sha strings onto LogMessage instances,
  # holding all the LogMessage instances ever created.
  all_logs = { }
  author = None
  date = None
  message = ''
  latest = None
  def __init__(self, sha):
    """Instantiate a log message.  All arguments are strings, including commit."""
    self.sha = sha
    # Map field names (e.g., "Patch", "Review") onto Field objects.
    self.fields = { }
    if not sha in LogMessage.all_logs:
      LogMessage.all_logs[sha] = self
  def add_field(self, field):
    self.fields[field.name] = field
  def accum(self, line):
    """Accumulate one more line of raw message."""
    self.message += line

  def __cmp__(self, other):
    """Compare two log messages by date, for sort().
    Return -1, 0 or 1 depending on whether a > b, a == b, or a < b.
    Note that this is reversed from normal sorting behavior, but it's
    what we want for reverse chronological ordering of revisions."""
    a = self.date
    b = other.date
    if a > b: return -1
    if a < b: return 1
    else:     return 0

  def sort_key(self):
    return self.date

  def __str__(self):
    s = '=' * 15
    header = ' COMMIT: %s | %s \n %s' % (self.sha, self.author, self.message)
    s += header
    s += '=' * 15
    s += '\n'
    for field_name in self.fields.keys():
      s += str(self.fields[field_name]) + '\n'
    s += '-' * 15
    s += '-' * len(header)
    s += '-' * 15
    s += '\n'
    return s

def process_aliases(aliases_input):
  line = aliases_input.readline()
  while line:
    aliases = line.split(',')
    c = Contributor.get(aliases.pop(0).strip(), None)
    for alias in aliases:
      c.add_aliases(alias.strip())
    line = aliases_input.readline()

def process_committers():
    committers_url = 'https://whimsy.apache.org/public/public_ldap_projects.json'
    names_url = 'https://whimsy.apache.org/public/icla-info.json'
    committers = json.loads(requests.get(committers_url).text)['projects']['cassandra']['members']
    names_json = json.loads(requests.get(names_url).text)['committers']
    for committer in committers:
        name = names_json.get(committer, committer)
        if committer in Contributor.all_contributors and not name in Contributor.all_contributors:
            c = Contributor.get(committer, None)
            c.add_aliases(name)
        else:
            c = Contributor.get(name, None)
            c.add_aliases(committer)
        c.is_committer = True


### Regexps to parse the logs. ##
log_header_re = re.compile('^commit ([0-9a-z]+)$')
patch_by_re = re.compile('(?:.*\n)*.*patch by ([^;]+)(;|,)', flags=re.IGNORECASE | re.MULTILINE)
reviewed_by_re = re.compile('(?:.*\n)*.*[;, ](?:review|test)(?:ed)? by ((?:.|\n)+?)(?=(?: |\n)+for(?: |\n)+(?:cassandra-|#[0-9]+))', flags=re.IGNORECASE | re.MULTILINE)
coauthored_by_re = re.compile(' *co-authored-by: ([^<]+)', re.IGNORECASE)

def graze(input):
  line = input.readline()
  log = None
  while line != '':
    m = log_header_re.match(line)
    if not m:
      sys.stderr.write('Could not match log message header.\n')
      sys.stderr.write('Line was:\n')
      sys.stderr.write("'%s'\n" % line)
      sys.exit(1)
    else:
      log = LogMessage(m.group(1))
      log.author = input.readline()
      log.date = parser.parse(input.readline().replace('Date: ', ''))
      if LogMessage.latest is None: LogMessage.latest = log.date
      patch_field = Field("Patch")
      review_field = Field("Review")
      # Parse the log message.
      while line != '':
        line = input.readline()
        if line == '\n': continue
        m = log_header_re.match(line)
        if m: 
            m = patch_by_re.match(log.message)
            if m:
                authors = re.split(',|&|( |\n)and( |\n)(by( |\n))?', m.group(1))
                for author in authors:
                    if author and not author.isspace():
                        c = Contributor.get(" ".join(author.strip().split()), None)
                        patch_field.add_contributor(c)
                        c.add_activity(patch_field, log)
                log.add_field(patch_field)
            m = reviewed_by_re.match(log.message)
            if m:
                reviewers = re.split(',|&|( |\n)and( |\n)(by( |\n))?', m.group(1))
                for reviewer in reviewers:
                    if reviewer and not reviewer.isspace():
                        c = Contributor.get(" ".join(reviewer.strip().split()), None)
                        review_field.add_contributor(c)
                        c.add_activity(review_field, log)
                log.add_field(review_field)
            for c in patch_field.contributors:
                c.add_collaboration(patch_field)
                c.add_collaboration(review_field)
            for c in review_field.contributors:
                c.add_collaboration(patch_field)
                c.add_collaboration(review_field)
            break
        log.accum(line)
        m = coauthored_by_re.match(line)
        if m:
            c = Contributor.get(" ".join(m.group(1).strip().split()), None)
            patch_field.add_contributor(c)
            log.add_field(patch_field)
            c.add_activity(patch_field, log)

#
# HTML output stuff.
#

index_introduction = '''
<p>Contributors and their contributions. Last push %s</p>
'''

def html_spam_guard(addr, entities_only=False):
  """Return a spam-protected version of email ADDR that renders the
  same in HTML as the original address.  If ENTITIES_ONLY, use a less
  thorough mangling scheme involving entities only, avoiding the use
  of tags."""
  if entities_only:
    def mangle(x):
      return "&#%d;" % ord (x)
  else:
    def mangle(x):
      return "<span>&#%d;</span>" % ord(x)
  return "".join(map(mangle, addr))


def escape_html(str):
  """Return an HTML-escaped version of STR."""
  return str.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')

_spam_guard_in_html_block_re = re.compile(r'&lt;([^&]*@[^&]*)&gt;')
def _spam_guard_in_html_block_func(m):
  return "&lt;%s&gt;" % html_spam_guard(m.group(1))
def spam_guard_in_html_block(str):
  """Take a block of HTML data, and run html_spam_guard() on parts of it."""
  return _spam_guard_in_html_block_re.subn(_spam_guard_in_html_block_func,
                                           str)[0]

def html_header(title, page_heading=None, highlight_targets=False):
#  Write HTML file header.  TITLE and PAGE_HEADING parameters are
#  expected to already by HTML-escaped if needed.  If HIGHLIGHT_TARGETS
# is true, then write out a style header that causes anchor targets to be
# surrounded by a red border when they are jumped to.
  if not page_heading:
    page_heading = title
  s  = '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"\n'
  s += ' "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">\n'
  s += '<html><head>\n'
  s += '<meta http-equiv="Content-Type"'
  s += ' content="text/html; charset=UTF-8" />\n'
  if highlight_targets:
    s += '<style type="text/css">\n'
    s += ':target { border: 2px solid red; }\n'
    s += '</style>\n'
  s += '<title>%s</title>\n' % title
  s += '</head>\n\n'
  s += '<body style="text-color: black; background-color: white">\n\n'
  s += '<h1 style="text-align: center">%s</h1>\n\n' % page_heading
  s += '<hr />\n\n'
  return s


def html_footer():
  return '\n</body>\n</html>\n'

def drop(title):
  # Output the data.
  #
  # The data structures are all linked up nicely to one another.  You
  # can get all the LogMessages, and each LogMessage contains all the
  # Contributors involved with that commit; likewise, each Contributor
  # points back to all the LogMessages it contributed to.
  #

  for key in LogMessage.all_logs.keys():
    # You could print out all log messages this way, if you wanted to.
    pass
    #print(LogMessage.all_logs[key])

  detail_subdir = "detail"
  if not os.path.exists(detail_subdir):
    os.mkdir(detail_subdir)

  index = open('index.html', 'w')
  index.write(html_header('Contributors %s' % title))
  index.write(index_introduction % LogMessage.latest)
  index.write('<ol>\n')
  # The same contributor appears under multiple keys, so uniquify.
  seen_contributors = { }
  # Sorting alphabetically is acceptable, but even better would be to
  # sort by number of contributions, so the most active people appear at
  # the top -- that way we know whom to look at first for commit access
  # proposals.
  sorted_contributors = sorted(Contributor.all_contributors.values(),
                               key=Contributor.sort_key,
                               reverse=True)
  for c in sorted_contributors:
    if c not in seen_contributors:
      urlpath = "%s/%s.html" % (detail_subdir, c.canonical_name())
      fname = os.path.join(detail_subdir, "%s.html" % c.canonical_name())
      if c.score() > 0:
        # Don't even bother to print out full committers.  They are
        # a distraction from the purposes for which we're here.
        if not c.is_committer:
          index.write('<li><p><a href="%s">%s</a>&nbsp;[%s]</p></li>\n'
                      % (urllib_parse_quote(urlpath),
                         c.big_name(html=True),
                         c.score_str()))
      c.html_out(fname, title)
      seen_contributors[c] = True
  index.write('</ol>\n')
  index.write(html_footer())
  index.close()

#
# Main stuff.
#

def usage():
  print('USAGE: git log --no-merges | %s [-t title]' \
        % os.path.basename(sys.argv[0]))
  print('')
  print('Create HTML files in the current directory, rooted at index.html,')
  print('in which you can browse to see who contributed what.')
  print('')


def main():
  try:
    opts, args = my_getopt(sys.argv[1:], 't:hH?', [ 'help' ])
  except getopt.GetoptError as e:
    complain(str(e) + '\n\n')
    usage()
    sys.exit(1)

  # Parse options.
  title = ''
  for opt, value in opts:
    if opt in ('--help', '-h', '-H', '-?'):
      usage()
      sys.exit(0)
    elif opt == '-t':
      title = value

  # Gather the data.
  process_aliases(open(os.path.join(os.path.realpath(os.path.join(os.getcwd(), os.path.dirname(__file__))),'contribulyze.aliases')))
  process_committers()
  graze(sys.stdin)

  # Output the data.
  drop(title)

if __name__ == '__main__':
  main()
