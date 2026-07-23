#!/bin/bash
set -e

bash build.sh cas  2>&1 | tee error.log
