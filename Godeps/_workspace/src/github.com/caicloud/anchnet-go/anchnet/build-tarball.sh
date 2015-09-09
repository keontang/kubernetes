#!/bin/bash

# Copyright 2015 anchnet-go authors. All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

# The script builds tarball release.
CAICLOUD_VERSION="2015-09-01"

ROOT=$(dirname "${BASH_SOURCE}")/..
cd ${ROOT}/anchnet

go build
mkdir caicloud-anchnet-gosdk && mv anchnet caicloud-anchnet-gosdk
tar cvzf caicloud-anchnet-gosdk-$CAICLOUD_VERSION.tar.gz caicloud-anchnet-gosdk
rm -rf anchnet caicloud-anchnet-gosdk

cd -
