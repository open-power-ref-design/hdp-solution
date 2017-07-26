#!/usr/bin/env python
# Copyright 2017 IBM Corp.
#
# All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# ------------------------------------------------------------------------------
# finalize_inputs_hostnames.py
#
# This module propagates hostname stem indications from the config.yml to the
# kickstart file.  This is required to allow the kickstart file to recognize
# the node type for a partiular node.  (A more robust method for accomplishing
# this is planned based on the node role and the particular server type.)
# ------------------------------------------------------------------------------

from __future__ import nested_scopes, generators, division, absolute_import, \
    with_statement, print_function, unicode_literals

import argparse
import sys
import os
import re
from shutil import copy2
import fileinput
import netaddr
import logging
import os
import os.path


def update_kickstart_files(cfg_file, distros_path, log_level):

    # read the hostname stems from the config.yml file
    # mapping is placed in global vars (lists) node_type and hostname_stem
    read_hostname_stems(cfg_file, log_level)

    for base_path, dirs, files in os.walk(distros_path):
        for name in files:
            if name.endswith('.ks'):
                abspath = os.path.join(base_path, name)
                update_kickstart_file(abspath, log_level)


def update_kickstart_file(ks_file, log_level): 

    logging.info('Updating kickstart file: '+ks_file)
    
    f = open(ks_file,'r')
 
    linenum = 0
    lines = []
    for line in f:
        linenum += 1
        line = modify_line(line,'# insert {{ HOSTNAME_STEM_MASTER }}','master')
        line = modify_line(line,'# insert {{ HOSTNAME_STEM_EDGE }}',  'edge')
        line = modify_line(line,'# insert {{ HOSTNAME_STEM_WORKER }}','worker')
        lines.append(line)

    f.close()

    # replace the file with the updated info
    f = open(ks_file,'w')
    f.writelines(lines)
    f.close()

    print('Updated kickstart file: '+ks_file)



def modify_line(line,search_key,node_type_key):
   
    lineo = line
    if search_key in line:
        
        try:
            i = node_type.index(node_type_key)
            hns = hostname_stem[i]
        except ValueError:
            hns = '{{HOSTNAME_STEM not found for '+node_type_key+' }}'  # create conditional that will never match in the ks
     
        p = line.split('"')
        lineo = p[0] + '"' + hns + '"' + p[2]

        logging.info('  Old line: '+line.rstrip())
        logging.info('  New line: '+lineo.rstrip())

    return lineo


def read_hostname_stems(cfg_file, log_level):

    f = open(cfg_file,'r')

    level = 0
    indent = [-1]
    context = ['']

    global node_type
    global hostname_stem

    node_type = []
    hostname_stem = []

    linenum = 0
    for line in f:
        linenum += 1
        if line.strip().startswith('#'):
            continue
        if line.strip() == '':
            continue

        n = countindent(line)

        # handle level changes
        if n > indent[level]:
            level += 1
            indent.append(n)
            context.append('')
        elif n < indent[level]:
            for m in reversed(range(level)):  # for each level below the current,
                # remove the previous level
                indent.pop()
                context.pop()
                if n == indent[m]: # if this is our new level,
                    level = m
                    break

            if n != indent[level]: # if we did not find a matching level,
                level = 0
                logging.error('ERROR: Improper indentation on line '+str(linenum))
                logging.error('>>>' + line)

        # parse at relevent points
        if level == 1:
            if line.strip().startswith('node-templates:'): # if this is the start of the 'node-templates' section
                context[level] = 'node-templates:'
            else:
                context[level] = ''

        if level == 2 and context[1] == 'node-templates:': # if these are the children of the node-template section,
            nt = line.strip().split(':')[0]
            node_type.append(nt)                             # pull the name of the node type
            hostname_stem.append('');                        # create a placeholder for the hostname (exactly one expected)

            if nt == 'master' or nt == 'edge' or nt == 'worker':
                pass # all is well
            else:
                logging.error('ERROR: Unrecognized node type "'+node_type[len(node_type)-1]+'" on line '+str(linenum))
                logging.error('>>>' + line)

        if level == 3 and context[1] == 'node-templates:': # if within the node type definitions,
            if line.strip().startswith('hostname:'):          # if this is a hostname entry,
                if hostname_stem[len(hostname_stem)-1] == '':   # if we are still seeking the hostname,
                    p = line.strip().split(':')                 # hostname: mn # comment
                    p = p[1].strip().split(' ')
                    hostname_stem[len(hostname_stem)-1] = p[0]
                else:
                    logging.error('ERROR: Additional hostname found for node type "'+node_type[len(node_type)-1]+'" on line '+str(linenum))
                    logging.error('>>>' + line)

    logging.info('node_types='+str(node_type))
    logging.info('hostname_stems='+str(hostname_stem))

    # confirm hostnames found for each node_type
    for i in range(len(hostname_stem)):
        if hostname_stem[i] == '':
            logging.error('ERROR: hostname not found for node type "'+node_type[i]+'"')

    f.close()


def countindent(s):
    return (len(s) - len(s.lstrip(' ')))


if __name__ == '__main__':

    """
    Arg1: config.yml file
    Arg2: distros path (directory)
    Arg3: log level
    """

    logging.basicConfig(filename='python.log', level=logging.INFO, format='%(asctime)s %(message)s')

    logging.info('Begin finalize_inputs_hostnames.py =================================================')

    ARGV_MAX = 4
    argv_count = len(sys.argv)

    oktocontinue = True

    if argv_count > 1:
        config_file = sys.argv[1]
        
        if not os.path.isfile(config_file):
            logging.error('First argument must be the path to the existing config.yml file.  Argument does not indicate a file: '+config_file)
            oktocontinue = False

    if argv_count > 2:
        distros_path = sys.argv[2].strip()

        if not os.path.isdir(distros_path):
            logging.error('Second argument must be the path to the existing distros directory.  Argument does not indicate a directory: '+distros_path)
            oktocontinue = False

    if argv_count > 3:  # currently ignored
        log_level = sys.argv[3]
    else:
        log_level = None

    if not oktocontinue:
        logging.error('Program terminating.')
        sys.exit(1)

    update_kickstart_files(
                   config_file,
                   distros_path,
                   log_level)

    sys.exit(0)
