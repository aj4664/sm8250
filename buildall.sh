#!/bin/bash
set -e

# Enable ccache
export CCACHE_DIR="$HOME/.cache/ccache_mikernel" 
export CC="ccache gcc"
export CXX="ccache g++"
export PATH="/usr/lib/ccache:$PATH"
ccache -M 50G

bash build.sh psyche
bash build.sh thyme
bash build.sh umi
bash build.sh munch
bash build.sh lmi
bash build.sh cmi
bash build.sh cas
bash build.sh apollo
bash build.sh alioth

bash build.sh psyche ksu
bash build.sh thyme ksu
bash build.sh umi ksu
bash build.sh munch ksu
bash build.sh lmi ksu
bash build.sh cmi ksu
bash build.sh cas ksu
bash build.sh apollo ksu
bash build.sh alioth ksu