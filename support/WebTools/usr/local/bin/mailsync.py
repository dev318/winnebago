#!/usr/bin/python
import threading
import subprocess
import time
import os
import re
import signal
import plistlib
from Cocoa import NSDictionary
from Foundation import NSData, \
                       NSPropertyListSerialization, \
                       NSPropertyListMutableContainers, \
                       NSPropertyListXMLFormat_v1_0

class FoundationPlistException(Exception):
    pass

class NSPropertyListSerializationException(FoundationPlistException):
    pass

class NSPropertyListWriteException(FoundationPlistException):
    pass

global debugEnabled
global thread
global plists
global path
debugEnabled = False 

imapsync = '/usr/local/bin/imapsync.pl'
mailOne = 'auxserxx.esss.lu.se'
mailTwo = 'mail01.esss.lu.se'
path = '/Shared Items/MigrationLogs/.usersync/'
thread = {}
plists = []

class MailSync(threading.Thread):
    def __init__(self):
        self.stdout = None
        self.stderr = None
        self.returncode = 192 
        threading.Thread.__init__(self)
    def run(self):
        if(debugEnabled): print 'Running command %s' % ' '.join(self.command)
        p = subprocess.Popen(self.command,
                             shell=False,
                             stdout=subprocess.PIPE,
                             stderr=subprocess.PIPE)

        self.stdout, self.stderr = p.communicate()
        self.returncode = p.returncode

def saveLog(filepath, contents):  
    filehandle = open(filepath, 'w')  
    filehandle.write(contents)  
    filehandle.close()

def plistNotification(signum, frame):
  print "Notification of plist modification"
  readPlists(path)
  return

def readPlist(filepath):
    """
    Read a .plist file from filepath.  Return the unpacked root object
    (which is usually a dictionary).
    """
    plistData = NSData.dataWithContentsOfFile_(filepath)
    dataObject, plistFormat, error = \
        NSPropertyListSerialization.propertyListFromData_mutabilityOption_format_errorDescription_(
                     plistData, NSPropertyListMutableContainers, None, None)
    if error:
        error = error.encode('ascii', 'ignore')
        errmsg = "%s in file %s" % (error, filepath)
        raise NSPropertyListSerializationException(errmsg)
    else:
        return dataObject

def convertPlist(pathToConvert):
  print 'Converting plist path %s to xml' % pathToConvert
  arguments = ["/usr/bin/plutil","-convert","xml1",pathToConvert]
  execute = subprocess.Popen(arguments, stdout=subprocess.PIPE)
  out, err = execute.communicate()

def readPlists(path): 
  print 'Refreshing plists'
  for (path, dirs, files) in os.walk(path):
    pattern = r'^.*\.plist$'
    for file in files:
      if re.search(pattern,file):
        plistPath = path + file
        convertPlist(plistPath)
        #plist = plistlib.readPlist(plistPath)
        plist = readPlist(plistPath)
        pidFile = '/private/tmp/%s-imapsync.pid' % plist['UserName']
        if os.path.exists(pidFile):
          print 'Sync is already running for %s' % plist['UserName']
        else:
          userName = plist['UserName']
          thread[userName] = MailSync()
          thread[userName].command = genCommand(plist)
          thread[userName].start()
          plists.append(plist)
  else:
  	print 'Completed refresh of user account database'

def genCommand(plist={}):
  pass_word = plist['Password']
  pass_word = pass_word.replace(u'\007','\\a')
  pidFile = '/private/tmp/%s-imapsync.pid' % plist['UserName']
  command = [imapsync,
  '--host1',
  mailOne,
  '--user1',
  plist['OldUserName'],
  '--password1',
  pass_word,
  '--host2',
  mailTwo,
  '--user2',
  plist['UserName'],
  '--password2',
  pass_word,
  '--authmech1',
  'CRAM-MD5',
  '--authmech2',
  'LOGIN',
  '--ssl2',
  '-subscribe',
  '-syncinternaldates',
  '--useuid',
  '--expunge2',
  '--delete2folders',
  '--regexflag',
  's/(\A[^\\\\]\w+\s)|(\s[^\\\\]\w+)//g',
  '--regextrans2',
  's/Sent Messages/Sent Items/g',
  '--exclude',
  'Shared',
  '--regextrans2',
  's/Trash/Deleted Items/g',
  '--pidfile',
   pidFile]
  if(debugEnabled): command.append('--debug')
  return command

# Register for our signals
signal.signal( signal.SIGUSR1, plistNotification )
# Read the intial plist directory
readPlists(path)
# Begin the infinate loop
while True:
  print '-' * 80
  print '| user' + ' ' * 67 + 'state |'
  print '-' * 80
  for plist in plists:
          userName = plist['UserName']
          if (thread[userName].isAlive()):
            state = 'processing'
            space = str((76 - len(userName) - len(state)) * ' ')
            print '| %s%s%s |' % (userName,space,state)
            print '-' * 80
            time.sleep(1)
          else:
            thread[userName].join()
            if (thread[userName].returncode == 0 ):
              state = 'complete'
            else:
              state = 'error %d' % thread[userName].returncode 
            space = str((76 - len(userName) - len(state)) * ' ')
            print '| %s%s%s |' % (userName,space,state)
            outPath = '/Shared Items/MigrationLogs/imap/%s-imapsync.log' % userName
            saveLog(outPath,thread[userName].stdout)
            errPath = '/Shared Items/MigrationLogs/imap/%s-imapsync.error.log' % userName 
            saveLog(errPath,thread[userName].stderr)
            print '-' * 80
            time.sleep(1)

  if not(debugEnabled):os.system('clear')
