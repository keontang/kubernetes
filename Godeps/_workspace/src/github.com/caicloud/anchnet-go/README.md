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

## Dependency Management
All dependencies in the client are vendored using [godep](https://github.com/tools/godep).

## Notes
The client library is not totally complete, but existing implementation has all the APIs necessary to bring up a cluster. We expect to add more as the project goes.
