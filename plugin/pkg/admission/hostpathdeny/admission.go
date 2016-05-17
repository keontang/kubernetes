/*
Copyright 2014 The Kubernetes Authors All rights reserved.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package hostpathdeny

import (
	"fmt"
	"io"

	clientset "k8s.io/kubernetes/pkg/client/clientset_generated/internalclientset"

	"k8s.io/kubernetes/pkg/admission"
	"k8s.io/kubernetes/pkg/api"
	apierrors "k8s.io/kubernetes/pkg/api/errors"
)

func init() {
	admission.RegisterPlugin("HostPathDeny", func(client clientset.Interface, config io.Reader) (admission.Interface, error) {
		return NewHostPathDeny(client), nil
	})
}

type plugin struct {
	*admission.Handler
	client clientset.Interface
}

// NewHostPathDeny returns an admission plugin which rejects any request with hostpath mount.
func NewHostPathDeny(client clientset.Interface) admission.Interface {
	return &plugin{
		Handler: admission.NewHandler(admission.Create, admission.Update),
		client:  client,
	}
}

func (p *plugin) Admit(a admission.Attributes) (err error) {
	if a.GetResource() != api.Resource("pods") {
		return nil
	}

	pod, ok := a.GetObject().(*api.Pod)
	if !ok {
		return apierrors.NewBadRequest("Resource was marked with kind Pod but was unable to be converted")
	}

	for _, v := range pod.Spec.Volumes {
		if v.VolumeSource.HostPath != nil {
			return apierrors.NewForbidden(a.GetResource(), pod.Name, fmt.Errorf("Unable to mount host path directory"))
		}
	}

	return nil
}
