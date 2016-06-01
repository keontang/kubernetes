# Caicloud scripts dockerfile.
FROM index.caicloud.io/caicloud/alpine:3.3

RUN apk add --update curl bash && rm -rf /var/cache/apk/*
ADD ./caicloud-kube-script /app/caicloud-kubernetes

WORKDIR /app
