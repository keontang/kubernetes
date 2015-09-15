# Caicloud kubernetes

## Overview

Caicloud kubernetes is a customized kubernetes hosted by [caicloud.io](https://caicloud.io). Currently, we support [Anchnet](http://cloud.51idc.com/), and there is
plan to add more cloudproviders. Kubernetes is the building block of caicloud.io, the long term plan is to enrich its ecosystem to enable enterprise use cases.

## How to do a release

To build release, run `./build-tarball.sh`. The script will build caicloud kubernetes binaries (kubelet, apiserver, etc) and scripts release (kube-up.sh, etc). For
example, following command will build tarballs tagged with version v1.0.1, and push to tool server.
```
./hack/caicloud/build-tarball.sh v1.0.1
```

If running without param, the script will print usage information for how to build tarballs, i.e.
```
./scripts/build-tarball.sh
```
