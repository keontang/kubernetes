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
	"encoding/json"
	"io"
	"time"

	"github.com/GoogleCloudPlatform/kubernetes/pkg/cloudprovider"

	anchnet_client "github.com/caicloud/anchnet-go"
)

const (
	ProviderName = "anchnet"

	// Number of retries when getting errors while accessing anchnet, e.g. request too frequent.
	RetryCountOnError = 5
	// Interval between two retries for the above situation.
	RetryIntervalOnError = 4 * time.Second

	// Number of retries when waitting on resources to become ready.
	RetryCountOnWaitReady = 30
	// Interval between two retries for the above situation.
	RetryIntervalOnWaitReady = 8 * time.Second
)

// TODO: Create cache layer to reduce calls to anchnet.
type Anchnet struct {
	client *anchnet_client.Client
}

func init() {
	cloudprovider.RegisterCloudProvider(ProviderName, func(config io.Reader) (cloudprovider.Interface, error) { return newAnchnet(config) })
}

// newAnchnet returns a new instance of Anchnet cloud provider.
func newAnchnet(config io.Reader) (cloudprovider.Interface, error) {
	var auth anchnet_client.AuthConfiguration
	if err := json.NewDecoder(config).Decode(&auth); err != nil {
		return nil, err
	}
	client, err := anchnet_client.NewClient(anchnet_client.DefaultEndpoint, &auth)
	if err != nil {
		return nil, err
	}
	return &Anchnet{client}, nil
}

//
// Following methods implement Cloudprovider.Interface. To make a cloud platform a
// kubernetes cloudprovider, it must implement the interface.
//
var _ cloudprovider.Interface = (*Anchnet)(nil)

// TCPLoadBalancer returns an implementation of Interface.TCPLoadBalancer for Anchnet cloud.
func (an *Anchnet) TCPLoadBalancer() (cloudprovider.TCPLoadBalancer, bool) {
	return an, true
}

// Instances returns an implementation of Interface.Instances for Anchnet cloud.
func (an *Anchnet) Instances() (cloudprovider.Instances, bool) {
	return an, true
}

// Zones returns an implementation of Interface.Zones for Anchnet cloud.
// This interface is used in servicecontroller to create load balancer. Zone
// information is passed to TCPLoadBalancer interface directly so kubernetes
// itself doesn't depend on Zones.
func (an *Anchnet) Zones() (cloudprovider.Zones, bool) {
	return an, true
}

// Clusters returns an implementation of Interface.Clusters for Anchnet cloud.
// This interface doesn't seem to be used in kubernetes, and a lot cloudproviders
// do not implement it, so we ignore it for now.
func (an *Anchnet) Clusters() (cloudprovider.Clusters, bool) {
	return nil, false
}

// Routes returns an implementation of Interface.Routes for Anchnet cloud.
// This interface is used in routecontroller to make sure Node has correct CIDR.
// In GCE, every node is assigned a CIDR, e.g. 10.200.10.0/24. This range will
// be used to create Pod IPs; therefore, each machine has a virtual container
// network. Anchnet doesn't support route configuration, and we use flannel to
// implement this CIDR, so we don't support the interface.
func (an *Anchnet) Routes() (cloudprovider.Routes, bool) {
	return nil, false
}

// ProviderName returns the cloud provider ID.
func (an *Anchnet) ProviderName() string {
	return ProviderName
}
