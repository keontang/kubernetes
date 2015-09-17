# Caicloud kubernetes

## Overview

Caicloud kubernetes is a customized kubernetes hosted by [caicloud.io](https://caicloud.io). Currently, we support [Anchnet](http://cloud.51idc.com/),
and there is plan to add more cloudproviders. Kubernetes is the building block of caicloud.io, the long term plan is to enrich its ecosystem to enable
enterprise use cases.

## How to do a release

To build release, use `./build-tarball.sh`. The script will build caicloud kubernetes binaries (kubelet, apiserver, etc) and scripts release
(kube-up.sh, kube-down.sh etc). To see its full description, run:
```
./build-tarball.sh help
```

E.g. following command will build tarballs tagged with version v1.0.1, and push to tool server (push to tool server is the default behavior):
```
./build-tarball.sh v1.0.1
```

If running without param, the script will build images with current date/time, this is useful during development. E.g. following command
will build images tagged with something like image:2015-09-10-18-15-30.
```
./build-tarball.sh
```
