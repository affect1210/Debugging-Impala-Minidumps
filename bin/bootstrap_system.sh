#!/bin/bash

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

# This script bootstraps a system for Impala development from almost nothing; it is known
# to work on Ubuntu 16.04. It clobbers some local environment and system
# configurations, so it is best to run this in a fresh install. It also sets up the
# ~/.bashrc for the calling user and impala-config-local.sh with some environment
# variables to make Impala compile and run after this script is complete.
# When IMPALA_TOOL_HOME is set, the script will bootstrap Impala development in the
# location specified.
#
# The intended user is a person who wants to start contributing code to Impala. This
# script serves as an executable reference point for how to get started.
#
# To run this in a Docker container:
#
#   1. Run with --privileged
#   2. Give the container a non-root sudoer wih NOPASSWD:
#      apt-get update
#      apt-get install sudo
#      adduser --disabled-password --gecos '' impdev
#      echo 'impdev ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers
#   3. Run this script as that user: su - impdev -c /bootstrap_development.sh
#
# This script has some specializations for CentOS/Redhat 6/7 and Ubuntu.
# Of note, inside of Docker, Redhat 7 doesn't allow you to start daemons
# with systemctl, so sshd and postgresql are started manually in those cases.

set -eu -o pipefail

: ${IMPALA_TOOL_HOME:=~/Impala}

if [[ -t 1 ]] # if on an interactive terminal
then
  echo "This script will clobber some system settings. Are you sure you want to"
  echo -n "continue? "
  while true
  do
    read -p "[yes/no] " ANSWER
    ANSWER=$(echo "$ANSWER" | tr /a-z/ /A-Z/)
    if [[ $ANSWER = YES ]]
    then
      break
    elif [[ $ANSWER = NO ]]
    then
      echo "OK, Bye!"
      exit 1
    fi
  done
fi

set -x

# Determine whether we're running on redhat or ubuntu
REDHAT=
REDHAT6=
REDHAT7=
UBUNTU=
UBUNTU16=
UBUNTU18=
IN_DOCKER=
if [[ -f /etc/redhat-release ]]; then
  REDHAT=true
  echo "Identified redhat system."
  if grep 'release 7\.' /etc/redhat-release; then
    REDHAT7=true
    echo "Identified redhat7 system."
  fi
  if grep 'release 6\.' /etc/redhat-release; then
    REDHAT6=true
    echo "Identified redhat6 system."
  fi
  # TODO: restrict redhat versions
else
  source /etc/lsb-release
  if [[ $DISTRIB_ID = Ubuntu ]]
  then
    UBUNTU=true
    echo "Identified Ubuntu system."
    # Kerberos setup would pop up dialog boxes without this
    export DEBIAN_FRONTEND=noninteractive
    if [[ $DISTRIB_RELEASE = 16.04 ]]
    then
      UBUNTU16=true
      echo "Identified Ubuntu 16.04 system."
    elif [[ $DISTRIB_RELEASE = 18.04 ]]
    then
      UBUNTU18=true
      echo "Identified Ubuntu 18.04 system."
    else
      echo "This script only supports 16.04 or 18.04 of Ubuntu" >&2
      exit 1
    fi
  else
    echo "This script only supports Ubuntu or RedHat" >&2
    exit 1
  fi
fi
if grep docker /proc/1/cgroup; then
  IN_DOCKER=true
  echo "Identified we are running inside of Docker."
fi

# Helper function to execute following command only on Ubuntu
function ubuntu {
  if [[ "$UBUNTU" == true ]]; then
    "$@"
  fi
}

# Helper function to execute following command only on Ubuntu 16.04
function ubuntu16 {
  if [[ "$UBUNTU16" == true ]]; then
    "$@"
  fi
}

# Helper function to execute following command only on Ubuntu 18.04
function ubuntu18 {
  if [[ "$UBUNTU18" == true ]]; then
    "$@"
  fi
}

# Helper function to execute following command only on RedHat
function redhat {
  if [[ "$REDHAT" == true ]]; then
    "$@"
  fi
}

# Helper function to execute following command only on RedHat6
function redhat6 {
  if [[ "$REDHAT6" == true ]]; then
    "$@"
  fi
}
# Helper function to execute following command only on RedHat7
function redhat7 {
  if [[ "$REDHAT7" == true ]]; then
    "$@"
  fi
}
# Helper function to execute following command only in docker
function indocker {
  if [[ "$IN_DOCKER" == true ]]; then
    "$@"
  fi
}
# Helper function to execute following command only outside of docker
function notindocker {
  if [[ "$IN_DOCKER" != true ]]; then
    "$@"
  fi
}

# Note that yum has its own retries; see yum.conf(5).
REAL_APT_GET=$(ubuntu which apt-get)
function apt-get {
  for ITER in $(seq 1 20); do
    echo "ATTEMPT: ${ITER}"
    if sudo -E "${REAL_APT_GET}" "$@"
    then
      return 0
    fi
    sleep "${ITER}"
  done
  echo "NO MORE RETRIES"
  return 1
}

echo ">>> Installing build tools"
ubuntu apt-get update
ubuntu apt-get --yes install python-dev python-setuptools wget apt-utils

redhat sudo yum install -y curl python-devel python-setuptools \
        wget redhat-lsb python-argparse

# Clean up yum caches
redhat sudo yum clean all

