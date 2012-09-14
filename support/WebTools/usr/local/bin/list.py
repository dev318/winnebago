#!/usr/bin/python
import os
import re
from Cocoa import NSDictionary

global debugEnabled
debugEnabled = True

imapsync = '/usr/local/bin/imapsync.pl'
mailOne = 'postfix.mailhost.com' 
mailTwo = 'exchange.mailhost.com'

def genCommand(plist={}):
  command = [imapsync,
  '--host1',
  mailOne,
  plist['OldUserName'],
  '--password1',
  plist['Password'],
  '--host2',
  mailTwo,
  '--user2',
  plist['UserName'],
  '--password2',
  plist['Password'],
  '--authmech1',
  'CRAM-MD5',
  '--authmech2',
  'LOGIN',
  '--ssl2',
  '-subscribe',
  '-syncinternaldates',
  '--useuid',
  '--delete2',
  ' --expunge2',
  '--delete2folders',
  """--regexflag 's/(\A[^\\]\w+\s)|(\s[^\\]\w+)//g""",
  '--regextrans2',
  """'s/Sent Messages/Sent Items/g'"""]
  return command

path = '/Shared Items/MigrationLogs/.usersync/'
for (path, dirs, files) in os.walk(path):
  pattern = r'^.*\.plist$'
  for file in files:
    if re.search(pattern,file):
      plistPath = path + file
      plist = NSDictionary.dictionaryWithContentsOfFile_(plistPath)
      print genCommand(plist)
