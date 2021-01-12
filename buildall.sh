#!/usr/bin/env bash
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

set -euo pipefail
. $IMPALA_HOME/bin/report_build_error.sh
setup_report_build_error

# run buildall.sh -help to see options
ROOT=`dirname "$0"`
ROOT=`cd "$ROOT" >/dev/null; pwd`

if [[ "'$ROOT'" =~ [[:blank:]] ]]
then
   echo "IMPALA_HOME cannot have spaces in the path"
   exit 1
fi

# Grab this *before* we source impala-config.sh to see if the caller has
# kerberized environment variables already or not.
NEEDS_RE_SOURCE_NOTE=1
: ${MINIKDC_REALM=}
if [[ ! -z "${MINIKDC_REALM}" ]]; then
  NEEDS_RE_SOURCE_NOTE=0
fi

export IMPALA_HOME="$ROOT"
if ! . "$ROOT"/bin/impala-config.sh; then
  echo "Bad configuration, aborting buildall."
  exit 1
fi

# Change to IMPALA_HOME so that coredumps, etc end up in IMPALA_HOME.
cd "${IMPALA_HOME}"

# Defaults that are only changable via the commandline.
CLEAN_ACTION=1
TESTDATA_ACTION=0
TESTS_ACTION=1
FORMAT_CLUSTER=0
FORMAT_METASTORE=0
FORMAT_SENTRY_POLICY_DB=0
FORMAT_RANGER_POLICY_DB=0
NEED_MINICLUSTER=0
START_IMPALA_CLUSTER=0
SNAPSHOT_FILE=
METASTORE_SNAPSHOT_FILE=
CODE_COVERAGE=0
BUILD_ASAN=0
BUILD_FE_ONLY=0
BUILD_TESTS=1
GEN_CMAKE_ONLY=0
BUILD_RELEASE_AND_DEBUG=0
BUILD_TIDY=0
BUILD_UBSAN=0
BUILD_UBSAN_FULL=0
BUILD_TSAN=0
BUILD_TSAN_FULL=0
BUILD_SHARED_LIBS=0
# Export MAKE_CMD so it is visible in scripts that invoke make, e.g. copy-udfs-udas.sh
export MAKE_CMD=make

# Defaults that can be picked up from the environment, but are overridable through the
# commandline.
: ${EXPLORATION_STRATEGY:=core}
: ${CMAKE_BUILD_TYPE:=Debug}

# parse command line options
while [ -n "$*" ]
do
  case "$1" in
    -noclean)
      CLEAN_ACTION=0
      ;;
    -testdata)
      TESTDATA_ACTION=1
      ;;
    -skiptests)
      TESTS_ACTION=0
      ;;
    -build_shared_libs|-so)
      BUILD_SHARED_LIBS=1
      ;;
    -notests)
      TESTS_ACTION=0
      BUILD_TESTS=0
      ;;
    -format)
      FORMAT_CLUSTER=1
      FORMAT_METASTORE=1
      FORMAT_SENTRY_POLICY_DB=1
      FORMAT_RANGER_POLICY_DB=1
      ;;
    -format_cluster)
      FORMAT_CLUSTER=1
      ;;
    -format_metastore)
      FORMAT_METASTORE=1
      ;;
    -format_sentry_policy_db)
      FORMAT_SENTRY_POLICY_DB=1
      ;;
    -format_ranger_policy_db)
      FORMAT_RANGER_POLICY_DB=1
      ;;
    -release)
      CMAKE_BUILD_TYPE=Release
      ;;
    -release_and_debug)
      BUILD_RELEASE_AND_DEBUG=1
      ;;
    -codecoverage)
      CODE_COVERAGE=1
      ;;
    -asan)
      BUILD_ASAN=1
      ;;
    -tidy)
      BUILD_TIDY=1
      ;;
    -ubsan)
      BUILD_UBSAN=1
      ;;
    -full_ubsan)
      BUILD_UBSAN_FULL=1
      ;;
    -tsan)
      BUILD_TSAN=1
      ;;
     -full_tsan)
      BUILD_TSAN_FULL=1
      ;;
    -testpairwise)
      EXPLORATION_STRATEGY=pairwise
      ;;
    -testexhaustive)
      EXPLORATION_STRATEGY=exhaustive
      # See bin/run-all-tests.sh and IMPALA-3947 for more information on
      # what this means.
      ;;
    -snapshot_file)
      SNAPSHOT_FILE="${2-}"
      if [[ ! -f "$SNAPSHOT_FILE" ]]; then
        echo "-snapshot_file does not exist: $SNAPSHOT_FILE"
        exit 1
      fi
      TESTDATA_ACTION=1
      # Get the full path.
      SNAPSHOT_FILE="$(readlink -f "$SNAPSHOT_FILE")"
      shift;
      ;;
    -metastore_snapshot_file)
      METASTORE_SNAPSHOT_FILE="${2-}"
      if [[ ! -f "$METASTORE_SNAPSHOT_FILE" ]]; then
        echo "-metastore_snapshot_file does not exist: $METASTORE_SNAPSHOT_FILE"
        exit 1
      fi
      TESTDATA_ACTION=1
      # Get the full path.
      METASTORE_SNAPSHOT_FILE="$(readlink -f "$METASTORE_SNAPSHOT_FILE")"
      shift;
      ;;
    -start_minicluster)
      NEED_MINICLUSTER=1
      ;;
    -start_impala_cluster)
      START_IMPALA_CLUSTER=1
      ;;
    -v|-debug)
      echo "Running in Debug mode"
      set -x
      ;;
    -fe_only)
      BUILD_FE_ONLY=1
      ;;
    -ninja)
      MAKE_CMD=ninja
      ;;
    -cmake_only)
      GEN_CMAKE_ONLY=1
      ;;
    -help|*)
      echo "buildall.sh - Builds Impala and runs all tests."
      echo "[-noclean] : Omits cleaning all packages before building. Will not kill"\
           "running Hadoop services unless any -format* is True"
      echo "[-format] : Format the minicluster, metastore db, and sentry policy db"\
           "[Default: False]"
      echo "[-format_cluster] : Format the minicluster [Default: False]"
      echo "[-format_metastore] : Format the metastore db [Default: False]"
      echo "[-format_sentry_policy_db] : Format the Sentry policy db [Default: False]"
      echo "[-format_ranger_policy_db] : Format the Ranger policy db [Default: False]"
      echo "[-release_and_debug] : Build both release and debug binaries. Overrides "\
           "other build types [Default: false]"
      echo "[-release] : Release build [Default: debug]"
      echo "[-codecoverage] : Build with code coverage [Default: False]"
      echo "[-asan] : Address sanitizer build [Default: False]"
      echo "[-tidy] : clang-tidy build [Default: False]"
      echo "[-tsan] : Thread sanitizer build, runs with"\
           "ignore_noninstrumented_modules=1. When this flag is true, TSAN ignores"\
           "memory accesses from non-instrumented libraries. This decreases the number"\
           "of false positives, but might miss real issues. -full_tsan disables this"\
           "flag [Default: False]"
      echo "[-full_tsan] : Thread sanitizer build, runs with"\
           "ignore_noninstrumented_modules=0 (see the -tsan description for an"\
           "explanation of what this flag does) [Default: False]"
      echo "[-ubsan] : Undefined behavior sanitizer build [Default: False]"
      echo "[-full_ubsan] : Undefined behavior sanitizer build, including code generated"\
           "by cross-compilation to LLVM IR. Much slower queries than plain -ubsan"\
           "[Default: False]"
      echo "[-skiptests] : Skips execution of all tests"
      echo "[-notests] : Skips building and execution of all tests"
      echo "[-start_minicluster] : Start test cluster including Impala and all"\
           "its dependencies. If already running, all services are restarted."\
           "Regenerates test cluster config files. [Default: True if running"\
           "tests or loading data, False otherwise]"
      echo "[-start_impala_cluster] : Start Impala minicluster after build"\
           "[Default: False]"
      echo "[-testpairwise] : Run tests in 'pairwise' mode (increases"\
           "test execution time)"
      echo "[-testexhaustive] : Run tests in 'exhaustive' mode, which significantly"\
           "increases test execution time. ONLY APPLIES to suites with workloads:"\
           "functional-query, targeted-stress"
      echo "[-testdata] : Loads test data. Implied as true if -snapshot_file is"\
           "specified. If -snapshot_file is not specified, data will be regenerated."
      echo "[-snapshot_file <file name>] : Load test data from a snapshot file"
      echo "[-metastore_snapshot_file <file_name>]: Load the hive metastore snapshot"
      echo "[-so|-build_shared_libs] : Dynamically link executables (default is static)"
      echo "[-fe_only] : Build just the frontend"
      echo "[-ninja] : Use ninja instead of make"
      echo "[-cmake_only] : Generate makefiles only, instead of doing a full build"
      echo "-----------------------------------------------------------------------------
Examples of common tasks:

  # Build and run all tests
  ./buildall.sh

  # Build and skip tests
  ./buildall.sh -skiptests

  # Build, then restart the minicluster and Impala with fresh configs.
  ./buildall.sh -notests -start_minicluster -start_impala_cluster

  # Incrementally rebuild and skip tests. Keeps existing minicluster services running
  # and restart Impala.
  ./buildall.sh -skiptests -noclean -start_impala_cluster

  # Build, load a snapshot file, run tests
  ./buildall.sh -snapshot_file <file>

  # Build, load the hive metastore and the hdfs snapshot, run tests
  ./buildall.sh -snapshot_file <file> -metastore_snapshot_file <file>

  # Build, generate, and incrementally load test data without formatting the mini-cluster
  # (reuses existing data in HDFS if it exists). Can be faster than loading from a
  # snapshot.
  ./buildall.sh -testdata

  # Build, format mini-cluster and metastore, load all test data, run tests
  ./buildall.sh -testdata -format"
      exit 1
      ;;
    esac
  shift;
done

bootstrap_dependencies() {
  # Populate necessary thirdparty components unless it's set to be skipped.
  if [[ "${SKIP_TOOLCHAIN_BOOTSTRAP}" = true ]]; then
    echo "SKIP_TOOLCHAIN_BOOTSTRAP is true, skipping download of Python dependencies."
    echo "SKIP_TOOLCHAIN_BOOTSTRAP is true, skipping toolchain bootstrap."
  else
    echo ">>> Downloading Python dependencies"
    # Download all the Python dependencies we need before doing anything
    # of substance. Does not re-download anything that is already present.
    if ! "$IMPALA_HOME/infra/python/deps/download_requirements"; then
      echo "Warning: Unable to download Python requirements."
      echo "Warning: bootstrap_virtualenv or other Python-based tooling may fail."
    else
      echo "Finished downloading Python dependencies"
    fi

    echo ">>> Downloading and extracting toolchain dependencies."
    "$IMPALA_HOME/bin/bootstrap_toolchain.py"
    echo "Toolchain bootstrap complete."
  fi
}


bootstrap_dependencies

