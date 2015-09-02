/*
Copyright 2015 The Kubernetes Authors All rights reserved.

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

package anchnet_cloud

import (
	"fmt"
	"strings"
	"time"
	"unicode"

	"k8s.io/kubernetes/pkg/api"
	"k8s.io/kubernetes/pkg/api/resource"

	anchnet_client "github.com/caicloud/anchnet-go"
	"github.com/golang/glog"
)

// WaitJobStatus waits until a job becomes desired status.
func (an *Anchnet) WaitJobStatus(jobID string, status anchnet_client.JobStatus) error {
	glog.Infof("Wait Job %v to become status %v", jobID, status)
	for i := 0; i < RetryCountOnWait; i++ {
		request := anchnet_client.DescribeJobsRequest{
			JobIDs: []string{jobID},
		}
		var response anchnet_client.DescribeJobsResponse
		err := an.client.SendRequest(request, &response)
		if err == nil {
			if len(response.ItemSet) == 0 {
				glog.Infof("Attempt %d: received nil error but empty response while waiting for job %v\n", i, jobID)
			} else if response.ItemSet[0].Status == status {
				glog.Infof("Job %v becomes desired status %v", jobID, status)
				return nil
			}
		} else {
			glog.Infof("Attempt %d: failed to wait job status: %v\n", i, err)
		}
		time.Sleep(time.Duration(i+1) * RetryIntervalOnWait)
	}
	return fmt.Errorf("Time out waiting for job %v", jobID)
}

// makeResources converts bare resources to api spec'd resource, cpu is in cores, memory is in GiB.
func makeResources(cpu, memory int) *api.NodeResources {
	return &api.NodeResources{
		Capacity: api.ResourceList{
			api.ResourceCPU:    *resource.NewMilliQuantity(int64(cpu*1000), resource.DecimalSI),
			api.ResourceMemory: *resource.NewQuantity(int64(memory*1024*1024*1024), resource.BinarySI),
		},
	}
}

// convertToInstanceID converts name to anchnet instance ID, e.g.
//   i-ff830wku->i-FF830WKU, i-FF830WKU->i-FF830WKU.
func convertToInstanceID(name string) string {
	s := strings.ToUpper(name)
	a := []rune(s)
	a[0] = unicode.ToLower(a[0])
	return string(a)
}
