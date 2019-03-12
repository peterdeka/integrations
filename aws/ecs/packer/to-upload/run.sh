#!/bin/bash

set -eu

LOGGER_TAG=""

succeed_or_die() {
    if ! OUT=$("$@" 2>&1); then
	echo "error: '$@' failed: $OUT" | logger -p local0.error -t $LOGGER_TAG
	exit 1
    fi
    echo $OUT
}

run_weave() {
  # launch weave
  PEERS=$(succeed_or_die /etc/weave/peers.sh)
  succeed_or_die weave launch --plugin=false --no-restart --hostname-from-label 'com.amazonaws.ecs.container-name' $PEERS
}

case $1 in
    weave)
	LOGGER_TAG="weave_runner"
        run_weave
        ;;
esac
