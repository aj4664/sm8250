#!/bin/bash
set -e

bash build.sh cas ksu  2>&1 | tee error.log
