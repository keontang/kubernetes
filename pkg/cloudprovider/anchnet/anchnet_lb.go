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
	"net"

	"github.com/GoogleCloudPlatform/kubernetes/pkg/api"
	"github.com/GoogleCloudPlatform/kubernetes/pkg/cloudprovider"
)

//
// Following methods implement Cloudprovider.TCPLoadBalancer.
//
var _ cloudprovider.TCPLoadBalancer = (*Anchnet)(nil)

// GetTCPLoadBalancer returns whether the specified load balancer exists,
// and if so, what its status is.
func (an *Anchnet) GetTCPLoadBalancer(name, region string) (status *api.LoadBalancerStatus, exists bool, err error) {
	return nil, false, nil
}

// CreateTCPLoadBalancer creates a new tcp load balancer. Returns the status of the balancer
func (an *Anchnet) CreateTCPLoadBalancer(name, region string, externalIP net.IP, ports []*api.ServicePort, hosts []string, affinityType api.ServiceAffinity) (*api.LoadBalancerStatus, error) {
	return nil, nil
}

// UpdateTCPLoadBalancer updates hosts under the specified load balancer.
func (an *Anchnet) UpdateTCPLoadBalancer(name, region string, hosts []string) error {
	return nil
}

// EnsureTCPLoadBalancerDeleted deletes the specified load balancer if it
// exists, returning nil if the load balancer specified either didn't exist or
// was successfully deleted.
// This construction is useful because many cloud providers' load balancers
// have multiple underlying components, meaning a Get could say that the LB
// doesn't exist even if some part of it is still laying around.
func (an *Anchnet) EnsureTCPLoadBalancerDeleted(name, region string) error {
	return nil
}
