#!/usr/bin/python -tt
__author__ = 'Zack Smith (zsmith@318.com)'
__version__ = '0.1'
import os
import sys
import getopt
import plistlib

global debugEnabled
global plist
global userName
global newPass
global templateFile
global saveFile
debugEnabled = True 

def main():
  if(debugEnabled): print 'Processing Arguments: ', sys.argv[1:]
  options, remainder = getopt.getopt(sys.argv[1:], 'w:f:u:p:', ['username=',
                                                         'password=',
                                                         'write=',
                                                         'file=',
                                                         ])
  for opt, arg in options:
    if opt in ('-u', '--username'):
      userName = arg 
    elif opt in ('-p', '--password'):
      newPass = arg
    elif opt in ('-w', '--write'):
      saveFile = arg
    elif opt in ('-f', '--file'):
      templateFile = arg 

  plist = plistlib.Plist.fromFile(templateFile)
  EAPClientConfiguration = plist['PayloadContent'][0]['EAPClientConfiguration']
  EAPClientConfiguration['UserName'] = userName
  EAPClientConfiguration['UserPassword'] = newPass
  plist.write(saveFile)
  return 0

if __name__ == "__main__":
  sys.exit(main())
