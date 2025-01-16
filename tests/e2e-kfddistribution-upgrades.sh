#!/usr/bin/env sh
# Copyright (c) 2017-present SIGHUP s.r.l All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

set -e

echo "----------------------------------------------------------------------------"
echo "Executing furyctl for the initial setup 1.29.5"
/tmp/furyctl apply --config tests/e2e/kfddistribution-upgrades/furyctl-init-cluster-1.29.5.yaml --outdir "$PWD" --disable-analytics

echo "----------------------------------------------------------------------------"
echo "Executing upgrade to 1.29.6"
# we set the switch date for Loki to "tomorrow". Notice that `-d flag` does not work on Darwin, you need to use `-v +1d` instead.
# this is needed only when upgrading from 1.29.5 to 1.29.6 (and equivalent versions)
/tmp/furyctl apply --upgrade --config tests/e2e/kfddistribution-upgrades/furyctl-init-cluster-1.29.6.yaml --outdir "$PWD" --distro-location ./ --force upgrades --disable-analytics
