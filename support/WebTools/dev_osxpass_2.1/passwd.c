/* version 2.1 */
/*  February 23, 2004
/*  - fixed problem with not properly handling encoded characters in posted data
/*  - changed interface to remove Apple logo and control panel icon

/* earlier versions */
/* version 2.0 */
/* The first version was based on a Perl CGI calling a command line program called xpass.  Following       
 * peer review of the web application it was determined that this was an insecure way of doing things.
 *
 * This version dispenses with the Perl CGI.  This CGI is entirely written in C.  No external programs are called.  
 * This also makes things simpler.  suexec is not required as in the first version.  
 * All that is required is that index.cgi and the folder of images be placed in a web accessible directory 
 * with the ability to execute CGIs enabled.
 */

/* Copyright (c) 2004 Dale Musser, eyebits studios
 * This source is derived from passwd from Apple Computer, Inc.
 * Therefore, it is subject to the Apple Public Source License
 * as indicated below.
 *---------------------------------------------------------------
 * eyebits studios
 * development@eyebits.com
 * http://eyebits.com
 * 336.272.5670
 * 301 S Elm St, Suite 510
 * Greensboro, NC 27401
 *---------------------------------------------------------------
 */
 
/*
 * Copyright (c) 1999 Apple Computer, Inc. All rights reserved.
 *
 * @APPLE_LICENSE_HEADER_START@
 * 
 * Copyright (c) 1999-2003 Apple Computer, Inc.  All Rights Reserved.
 * 
 * This file contains Original Code and/or Modifications of Original Code
 * as defined in and that are subject to the Apple Public Source License
 * Version 2.0 (the 'License'). You may not use this file except in
 * compliance with the License. Please obtain a copy of the License at
 * http://www.opensource.apple.com/apsl/ and read it before using this
 * file.
 * 
 * The Original Code and all software distributed under the License are
 * distributed on an 'AS IS' basis, WITHOUT WARRANTY OF ANY KIND, EITHER
 * EXPRESS OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES,
 * INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE, QUIET ENJOYMENT OR NON-INFRINGEMENT.
 * Please see the License for the specific language governing rights and
 * limitations under the License.
 * 
 * @APPLE_LICENSE_HEADER_END@
 */

#include <stdio.h>
#include <errno.h>
#include <pwd.h>
#include <libc.h>
#include <ctype.h>
#include <string.h>
#include "stringops.h"

#define MAXINPUT 1024   // form input data from POST can be no longer than this

extern int ds_passwd(char *, char *, char *, char *);
extern void create_page(char *);

int main(int argc, char *argv[])
{
	char *user, *locn;
        char *old_clear, *new_clear, *new_pw1;
        
        char *len_str;
        long len;
        char input[MAXINPUT+16];  // extended end of buffer to be longer than MAXINPUT
        char buffer[MAXINPUT+16]; 
        char *src, *last, *dest;
        char *varname, *varval;
        char *action;
        
        int i;
        
        user = NULL;
	locn = NULL;
        old_clear = NULL;
        new_clear = NULL;
        new_pw1 = NULL;
        action = NULL;
    
        
        // fill buffer with NULLs
        dest = buffer;
        for (i = 0; i < MAXINPUT+16; i++) {
            *dest = NULL;
            dest++;
        }
        
        printf("%s%c%c\n", "Content-type:text/html;charset=iso-8859-1",13,10);
        
        
        len_str = getenv("CONTENT_LENGTH");
        if(len_str == NULL || sscanf(len_str,"%ld",&len)!=1 || len > MAXINPUT) {
            create_page("");
            exit(0);
        }
        
        fgets(input, len+1, stdin);
        src = input;
        last = src + len;
        dest = buffer;
        
        varname = dest; 
        varval  = NULL;
        while ( src != last) {
           if (*src == '=') {
                *dest = '\0';
                varval = ++dest;
                src++;
                
           } else if (*src == '&') {
                *dest = '\0';
                if (!strcmp(varname, "uname")) {
                    user = varval;
                } else if (!strcmp(varname, "old_pw")) {
                    old_clear = varval;
                } else if(!strcmp(varname, "new_pw1")) {
                    new_pw1 = varval;
                } else if(!strcmp(varname, "action")) {
                    action = varval;
                }
                varname = ++dest;
                src++;
           
           } else {
                if (*src == '+') {
                    *dest = ' ';
                    dest++;
                    src++;
                } else if (*src == '%') {
                    int code;
                    if (sscanf(src+1, "%2x", &code) != 1) { // not valid code in string
                        create_page("Password change not successful.  Please try again.");
                        exit(0);
                    }
                    *dest = code;
                    dest++;
                    src += 3;
                } else {
                    *dest = *src;
                    dest++;
                    src++;
                }
           
           }
        }
      
                      
        if (action == NULL || strcmp(action, "xpass")) {
            create_page("");
            exit(0);
        }
        
        if (user == NULL || old_clear == NULL || new_pw1 == NULL ) {
            create_page("Missing piece of information.  Please try again.");
            exit(0);
        }
        // Updated to compare strings
        if (!strcmp(old_clear, new_pw1)) {
            new_clear = new_pw1;
        } else {
            create_page("Password fields do not match.  Please try again.");
            exit(0);
        }
        
        /* since DirectoryServices works for most infosystems, it is the one being used */
        if (ds_passwd(user, locn, old_clear, new_clear)) {
            create_page("Your password has been migrated successfully");

        } else {
            create_page("Password migration not successful.  Either ID or password was incorrect. Please try again.");
        }
        exit(0);
}

