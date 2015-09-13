# Caicloud Tools

The directory contains various tools for working with caicloud kubernetes.

- `caicloud-version.sh`:
  The script defines caicloud kubernetes versions and release hosting URLs.

- `build-tarball.sh`
  The script builds caicloud binary and kube-up releases. It depends on `caicloud-version.sh` for building. To build tarball, simply run:
  ```
  $ ./hack/caicloud-tools/build-tarball.sh
  ```
  Version is default to "`TZ=Asia/Shanghai date +%Y-%m-%d-%H-%M`", as defined in `caicloud-version.sh`. The tarball will be pushed to remote host or CDN, which are
  controlled by two parameters `UPLOAD_TO_QINIU` and `UPLOAD_TO_TOOLSERVER`. By default, we only upload to toolserver. E.g. to build a new release:
  ```
  UPLOAD_TO_QINIU=Y CAICLOUD_VERSION=v0.1.0 ./hack/caicloud-tools/build-tarball.sh
  ```
  This will build two tarballs `caicloud-kube-v0.1.0.tar.gz` and `caicloud-kube-executor-v0.1.0.tar.gz`.

- `k8s-replace.sh`, `k8s-restore`: The two scripts work around mainland network connection.

- `sync-images.sh`: The script pulls images from gcr.io (blocked by GFW) and push to dockerhub. This is required since kubernetes examples, e2e tests depend on
  thoese images.

- `qiniu-conf.json`: Credentials for pushing release tarball to qiniu.

- `caicloud-e2e-test.sh`
  The script is used for caicloud e2e test. The original e2e test script is located at [hack/e2e-test.sh](https://github.com/caicloud/caicloud-kubernetes/blob/master/hack/e2e-test.sh). To run our e2e test, just do the following:
  ```
  KUBE_RELEASE_RUN_TESTS=n KUBERNETES_PROVIDER=anchnet ./hack/caicloud-tools/caicloud-e2e-test.sh
  ```
  e2e tests are located at `test/e2e`. Test cases can be disabled using `--test_args="--ginkgo.skip=${CAICLOUD_TEST_SKIP_REGEX}"` flag. 
  If test case is not needed, we can add it to `CAICLOUD_TEST_SKIP_REGEX`. e.g.
  ```
  CAICLOUD_TEST_SKIP_REGEX="kube-ui|Cluster\slevel\slogging"
  ```
  will disable [elasticsearch](https://github.com/caicloud/caicloud-kubernetes/blob/master/test/e2e/es_cluster_logging.go#L34) & [kube-ui](https://github.com/caicloud/caicloud-kubernetes/blob/master/test/e2e/kube-ui.go#L30) tests. `--test_args="--ginkgo.focus=${REGEX}"` can be use to only run tests that match the regex.