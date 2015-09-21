# Change Log

All notable changes to this project will be documented in this file. This project adheres to [Semantic Versioning](http://semver.org/).

### Version 0.2.0 [TBD]
#### Changed
- Rename `hack/caicloud-tools` to `hack/caicloud`, since it's not just tools now.
- Rename `CAICLOUD_VERSION` to `CAICLOUD_KUBE_VERSION` to make it more explicit.
- Add new variable `BUILD_TARBALL` to replace the semantic of empty `CAICLOUD_VERSION`.
- Add kube-up, kube-down timestamp.
- Deprecate etcd on node.
- Reorg addon directory (add subdirectory), e.g. cluster/anchnet/addons/dns
- Remove executor-config.sh and move its configs to config-default.sh
- Support `ENABLE_CLUSTER_DNS`, `ENABLE_CLUSTER_LOGGING` params

### Version 0.1.0 [2015-09-12]
#### Changed
- Initial release of caicloud kubernetes, based on upstream tag [52ef059](https://github.com/caicloud/caicloud-kubernetes/commit/52ef0599d8c976993b3d8ac5c1e783bdb5cb2c83)
