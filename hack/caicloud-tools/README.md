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
