# Go client for anchnet API

Go client library for [anchnet](http://cloud.51idc.com/help/api/api_list.html)

## Overview

The library preserves all semantics from anchnet APIs, even though some of their APIs are inconsistent. E.g. They use volume and harddisk interchangeably.

`anchnet/` is the CLI tool implementation based on the client, see [README](anchnet/README.md)

## Authentication
Authentication is done reading a config file `~/.anchnet/config`. Example file:
```json
{
  "publickey":  "U9WGEXYO19ysz607rLXwOyC",
  "privatekey": "K4XX2OPKMA2VrMo4WjLFbRMMH3djEfW94LK4d1W"
}
```

## How to do a build release

To build a newer version, simply run
```
UPLOAD_TO_QINIU=Y ./anchnet/build-tarball.sh v1.0.1
```
This will create two release tarballs `anchnet-go-darwin-amd64-v1.0.1.tar.gz` and `anchnet-go-linux-amd64-v1.0.1.tar.gz` under `_output` directory, and
push the tarball to toolserver and qiniu (push to qiniu is optional). The script will check version and in case of error, it will print out usage
information, e.g.
```
$ ./anchnet/build-tarball.sh
Error: caicloud version must be provided.

Usage:
  ./build-tarball.sh vesion

Parameter:
  version        Tarball release version, must in the form of vA.B.C, where A, B, C are digits, e.g. v1.0.1
  ...
  ...
```

## Notes

The client library is not totally complete, but existing implementation has all the APIs necessary to bring up a cluster. We expect to add more as the project goes.
