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
	"testing"

	"k8s.io/kubernetes/pkg/admission"
	"k8s.io/kubernetes/pkg/api"
)

func TestAdmission(t *testing.T) {
	handler := NewHostPathDeny(nil)

	cases := []struct {
		name        string
		volumes     []api.Volume
		expectError bool
	}{
		{
			name: "unset",
		},
		{
			name:    "empty pod.Volume",
			volumes: []api.Volume{},
		},
		{
			name: "non hostpath volume",
			volumes: []api.Volume{
				api.Volume{Name: "nonhostpath", VolumeSource: api.VolumeSource{EmptyDir: &api.EmptyDirVolumeSource{}}},
			},
		},
		{
			name: "with hostpath",
			volumes: []api.Volume{
				api.Volume{Name: "acceptable", VolumeSource: api.VolumeSource{HostPath: &api.HostPathVolumeSource{Path: "/home/acceptable"}}},
			},
			expectError: true,
		},
		{
			name: "mixed",
			volumes: []api.Volume{
				api.Volume{Name: "nonhostpath", VolumeSource: api.VolumeSource{EmptyDir: &api.EmptyDirVolumeSource{}}},
				api.Volume{Name: "hostpath1", VolumeSource: api.VolumeSource{HostPath: &api.HostPathVolumeSource{Path: "/home"}}},
				api.Volume{Name: "hostpath2", VolumeSource: api.VolumeSource{HostPath: &api.HostPathVolumeSource{Path: "/etc/kubernetes"}}},
			},
			expectError: true,
		},
	}

	for _, tc := range cases {
		pod := pod()
		pod.Spec.Volumes = tc.volumes

		err := handler.Admit(admission.NewAttributesRecord(pod, api.Kind("Pod"), "foo", "name", api.Resource("pods"), "", "ignored", nil))
		if err != nil && !tc.expectError {
			t.Errorf("%v: unexpected error: %v", tc.name, err)
		} else if err == nil && tc.expectError {
			t.Errorf("%v: expected error", tc.name)
		}
	}
}

func TestHandles(t *testing.T) {
	handler := NewHostPathDeny(nil)
	tests := map[admission.Operation]bool{
		admission.Update:  true,
		admission.Create:  true,
		admission.Delete:  false,
		admission.Connect: false,
	}
	for op, expected := range tests {
		result := handler.Handles(op)
		if result != expected {
			t.Errorf("Unexpected result for operation %s: %v\n", op, result)
		}
	}
}

func pod() *api.Pod {
	return &api.Pod{
		Spec: api.PodSpec{
			Containers: []api.Container{
				{},
			},
		},
	}
}
