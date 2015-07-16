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
	"net"
	"time"

	"github.com/GoogleCloudPlatform/kubernetes/pkg/api"
	"github.com/GoogleCloudPlatform/kubernetes/pkg/cloudprovider"
	"github.com/golang/glog"

	anchnet_client "github.com/caicloud/anchnet-go"
)

//
// Following methods implement Cloudprovider.TCPLoadBalancer.
//
var _ cloudprovider.TCPLoadBalancer = (*Anchnet)(nil)

// GetTCPLoadBalancer returns whether the specified load balancer exists,
// and if so, what its status is.
func (an *Anchnet) GetTCPLoadBalancer(name, region string) (status *api.LoadBalancerStatus, exists bool, err error) {
	lb_response, exists, err := an.searchLoadBalancer(name)
	if err != nil {
		return nil, false, err
	}
	if exists == false {
		return nil, false, nil
	}
	// No external IP for the loadbalancer, shouldn't happen.
	if len(lb_response.ItemSet[0].Eips) == 0 {
		return nil, false, fmt.Errorf("External loadbalancer has no public IP")
	}
	err = an.waitForLoadBalancerReady(lb_response.ItemSet[0].LoadbalancerID)
	if err != nil {
		return nil, false, err
	}
	ip_response, err := an.describeEip(lb_response.ItemSet[0].Eips[0].EipID)
	if err != nil {
		return nil, false, err
	}

	status = &api.LoadBalancerStatus{}
	status.Ingress = []api.LoadBalancerIngress{{IP: ip_response.ItemSet[0].EipAddr}}
	glog.Infof("Anchnet: get loadbalancer %v, ingress ip %v\n", name, ip_response.ItemSet[0].EipAddr)
	return status, true, nil
}

// CreateTCPLoadBalancer creates a new tcp load balancer. Returns the status of the balancer.
// 'region' is returned from Zone interface and it's not used here, since anchnet only supports
// one zone. If it starts supporting multiple zones, we just need to update the request.
// 'externalIP' is not used, we use external IP given by anchnent.
// To create a TCP LoadBalancer for kubernetes, we do the following:
// 1. create external ip;
// 2. create a loadbalancer with that ip;
// 3. add listeners for the loadbalancer, number of listeners = number of service ports;
// 4. add backends for each listener.
// TODO: Try to apply affinityType.
func (an *Anchnet) CreateTCPLoadBalancer(name, region string, externalIP net.IP, ports []*api.ServicePort, hosts []string, affinityType api.ServiceAffinity) (*api.LoadBalancerStatus, error) {
	glog.Infof("Anchnet: received create loadbalancer request with name %v\n", name)

	// Anchnet doesn't support UDP (k8s doesn't support neither).
	for i := range ports {
		port := ports[i]
		if port.Protocol != api.ProtocolTCP {
			return nil, fmt.Errorf("external load balancers for non TCP services are not currently supported.")
		}
	}

	// Create a public IP address resource. The externalIP field is thus ignored.
	ip_response, err := an.allocateEIP()
	if err != nil {
		return nil, err
	}

	// Create a loadbalancer using the above external IP.
	lb_response, err := an.createLoadBalancer(name, ip_response.EipIDs[0])
	if err != nil {
		an.releaseEIP(ip_response.EipIDs[0])
		return nil, err
	}

	// Adding listeners and backends do not need loadbalancer to be ready, but updating
	// loadbalancer to apply the changes do require.
	err = an.waitForLoadBalancerReady(lb_response.LoadbalancerID)
	if err != nil {
		an.deleteLoadBalancer(lb_response.LoadbalancerID, ip_response.EipIDs[0])
		return nil, err
	}

	// Create listeners for the loadbalancer. Listener specifies which protocol and
	// which port the loadbalancer will listen to. A loadbalander can have multiple
	// listeners.

	// For every port, we need a listener. Note because we do not know the order of
	// listener IDs returned from anchnet, we create listener one by one.
	for _, port := range ports {
		listener_response, err := an.addLoadBalancerListeners(lb_response.LoadbalancerID, port.Port)
		if err != nil {
			an.deleteLoadBalancer(lb_response.LoadbalancerID, ip_response.EipIDs[0])
			return nil, err
		}
		backends := []anchnet_client.AddLoadBalancerBackendsBackend{}
		for _, host := range hosts {
			backend := anchnet_client.AddLoadBalancerBackendsBackend{
				ResourceID: convertToInstanceID(host),
				Port:       port.NodePort,
				Weight:     1, // Evenly spread
			}
			backends = append(backends, backend)
		}
		_, err = an.addLoadBalancerBackends(listener_response.ListenerIDs[0], backends)
		if err != nil {
			an.deleteLoadBalancer(lb_response.LoadbalancerID, ip_response.EipIDs[0])
			return nil, err
		}
	}

	_, err = an.updateLoadBalancer(lb_response.LoadbalancerID)
	if err != nil {
		an.deleteLoadBalancer(lb_response.LoadbalancerID, ip_response.EipIDs[0])
		return nil, err
	}

	response, err := an.describeEip(ip_response.EipIDs[0])
	if err != nil {
		an.deleteLoadBalancer(lb_response.LoadbalancerID, ip_response.EipIDs[0])
		return nil, err
	}

	status := &api.LoadBalancerStatus{}
	status.Ingress = []api.LoadBalancerIngress{{IP: response.ItemSet[0].EipAddr}}
	glog.Infof("Anchnet: created loadbalancer %v, ingress ip %v\n", name, response.ItemSet[0].EipAddr)
	return status, nil
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

// allocateEIP creates an external IP from anchnet, with retry.
func (an *Anchnet) allocateEIP() (*anchnet_client.AllocateEipsResponse, error) {
	for i := 0; i < RetryCountOnError; i++ {
		request := anchnet_client.AllocateEipsRequest{
			Product: anchnet_client.AllocateEipsProduct{
				IP: anchnet_client.AllocateEipsIP{
					IPGroup:   "eipg-00000000",
					Bandwidth: 1, // Hard-coded bandwith
					Amount:    1,
				},
			},
		}
		var response anchnet_client.AllocateEipsResponse
		err := an.client.SendRequest(request, &response)
		if err == nil {
			if len(response.EipIDs) == 0 {
				glog.Errorf("Attemp %d: received nil error but empty response while allocating eip\n", i)
			} else {
				glog.Infof("Allocated EIP with ID: %v", response.EipIDs[0])
				return &response, nil
			}
		} else {
			glog.Errorf("Attemp %d: failed to allocate eip: %v\n", i, err)
		}
		time.Sleep(RetryIntervalOnError)
	}
	return nil, fmt.Errorf("Unable to allocate eip")
}

// releaseEIP releasees an external IP from anchnet, with retry.
func (an *Anchnet) releaseEIP(eip string) (*anchnet_client.ReleaseEipsResponse, error) {
	for i := 0; i < RetryCountOnError; i++ {
		request := anchnet_client.ReleaseEipsRequest{
			EipIDs: []string{eip},
		}
		var response anchnet_client.ReleaseEipsResponse
		err := an.client.SendRequest(request, &response)
		if err == nil {
			return &response, nil
		} else {
			glog.Errorf("Attemp %d: failed to release eip: %v\n", i, err)
		}
		time.Sleep(RetryIntervalOnError)
	}
	return nil, fmt.Errorf("Unable to release eip")
}

// describeEip returns details of eip from anchnet, with retry.
func (an *Anchnet) describeEip(eip string) (*anchnet_client.DescribeEipsResponse, error) {
	for i := 0; i < RetryCountOnError; i++ {
		request := anchnet_client.DescribeEipsRequest{
			EipIDs: []string{eip},
		}
		var response anchnet_client.DescribeEipsResponse
		err := an.client.SendRequest(request, &response)
		if err == nil {
			if len(response.ItemSet) == 0 {
				return nil, fmt.Errorf("EIP %v doesn't exist\n", eip)
			} else {
				return &response, nil
			}
		}
		glog.Errorf("Attemp %d: failed to describe eip %v: %v\n", i, eip, err)
		time.Sleep(RetryIntervalOnError)
	}
	return nil, fmt.Errorf("Unable to find EIP %v\n", eip)
}

// createLoadBalancer creates a loadbalancer with given eip, with retry.
func (an *Anchnet) createLoadBalancer(name string, eip string) (*anchnet_client.CreateLoadBalancerResponse, error) {
	for i := 0; i < RetryCountOnError; i++ {
		request := anchnet_client.CreateLoadBalancerRequest{
			Product: anchnet_client.CreateLoadBalancerProduct{
				Loadbalancer: anchnet_client.CreateLoadBalancerLB{Name: name, Type: 1}, // Hard-coded type
				Eips:         []anchnet_client.CreateLoadBalancerIP{{RefID: eip}},
			},
		}
		var response anchnet_client.CreateLoadBalancerResponse
		err := an.client.SendRequest(request, &response)
		if err == nil {
			glog.Infof("Created loadbalancer with ID: %v", response.LoadbalancerID)
			return &response, nil
		} else {
			glog.Errorf("Attemp %d: failed to create loadbalancer: %v\n", i, err)
		}
		time.Sleep(RetryIntervalOnError)
	}
	return nil, fmt.Errorf("Unable to create loadbalancer %v with eip %v\n", name, eip)
}

// createLoadBalancer deletes a loadbalancer and its eip, with retry.
func (an *Anchnet) deleteLoadBalancer(lbID, eip string) (*anchnet_client.DeleteLoadBalancersResponse, error) {
	for i := 0; i < RetryCountOnError; i++ {
		request := anchnet_client.DeleteLoadBalancersRequest{
			EipIDs:          []string{eip},
			LoadbalancerIDs: []string{lbID},
		}
		var response anchnet_client.DeleteLoadBalancersResponse
		err := an.client.SendRequest(request, &response)
		if err == nil {
			glog.Infof("Deleted loadbalancer with ID: %v", lbID)
			return &response, nil
		} else {
			glog.Errorf("Attemp %d: failed to delete loadbalancer: %v\n", i, err)
		}
		time.Sleep(RetryIntervalOnError)
	}
	return nil, fmt.Errorf("Unable to delete loadbalancer %v with eip %v\n", lbID, eip)
}

// describeLoadBalancer gets a loadbalancer and its eip, with retry.
func (an *Anchnet) searchLoadBalancer(search_word string) (*anchnet_client.DescribeLoadBalancersResponse, bool, error) {
	for i := 0; i < RetryCountOnError; i++ {
		request := anchnet_client.DescribeLoadBalancersRequest{
			SearchWord: search_word,
		}
		var response anchnet_client.DescribeLoadBalancersResponse
		err := an.client.SendRequest(request, &response)
		if err == nil {
			if len(response.ItemSet) == 0 {
				return nil, false, nil
			} else {
				glog.Infof("Get loadbalancer with name: %v", search_word)
				return &response, true, nil
			}
		} else {
			glog.Errorf("Attemp %d: failed to get loadbalancer %v: %v\n", i, search_word, err)
		}
		time.Sleep(RetryIntervalOnWaitReady)
	}
	return nil, false, fmt.Errorf("Unable to get loadbalancer %v", search_word)
}

// addLoadBalancerListeners creates and adds a listener to given loadbalancer, with retry
func (an *Anchnet) addLoadBalancerListeners(lbID string, port int) (*anchnet_client.AddLoadBalancerListenersResponse, error) {
	for i := 0; i < RetryCountOnError; i++ {
		request := anchnet_client.AddLoadBalancerListenersRequest{
			LoadbalancerID: lbID,
			Listeners: []anchnet_client.AddLoadBalancerListenersListener{
				{
					ListenerName: fmt.Sprintf("%s-%d", lbID, port),
					ListenerOptions: anchnet_client.ListenerOptions{
						ListenerProtocol: anchnet_client.ListenerProtocolTypeTCP, // We've made sure there is only TCP port
						ListenerPort:     port,                                   // Port that listener (lb) will listen to
						Timeout:          600,                                    // Connection timeout
					},
				},
			},
		}
		var response anchnet_client.AddLoadBalancerListenersResponse
		err := an.client.SendRequest(request, &response)
		if err == nil {
			if len(response.ListenerIDs) == 0 {
				glog.Errorf("Attemp %d: received nil error but empty response while adding listeners\n", i)
			} else {
				glog.Infof("Created listener with ID: %v", response.ListenerIDs[0])
				return &response, nil
			}
		} else {
			glog.Errorf("Attemp %d: failed to add listener: %v\n", i, err)
		}
		time.Sleep(RetryIntervalOnError)
	}
	return nil, fmt.Errorf("Unable to add listener for loadbalancer %v\n", lbID)
}

// addLoadBalancerBackends creates and adds a backend to given listener, with retry.
func (an *Anchnet) addLoadBalancerBackends(listenerID string, backends []anchnet_client.AddLoadBalancerBackendsBackend) (*anchnet_client.AddLoadBalancerBackendsResponse, error) {
	for i := 0; i < RetryCountOnError; i++ {
		request := anchnet_client.AddLoadBalancerBackendsRequest{
			ListenerID: listenerID,
			Backends:   backends,
		}
		var response anchnet_client.AddLoadBalancerBackendsResponse
		err := an.client.SendRequest(request, &response)
		if err == nil {
			if len(response.BackendIDs) == 0 {
				glog.Errorf("Attemp %d: received nil error but empty response while adding backends\n", i)
			} else {
				glog.Infof("Added backends with IDs: %+v", response.BackendIDs)
				return &response, nil
			}
		} else {
			glog.Errorf("Attemp %d: failed to add backend: %v\n", i, err)
		}
		time.Sleep(RetryIntervalOnError)
	}
	return nil, fmt.Errorf("Unable to add backends %+v to listener %v\n", backends, listenerID)
}

// updateLoadBalancer updates changes to loadbalancer, with retry.
func (an *Anchnet) updateLoadBalancer(lbID string) (*anchnet_client.UpdateLoadBalancersResponse, error) {
	for i := 0; i < RetryCountOnError; i++ {
		request := anchnet_client.UpdateLoadBalancersRequest{
			LoadbalancerIDs: []string{lbID},
		}
		var response anchnet_client.UpdateLoadBalancersResponse
		err := an.client.SendRequest(request, &response)
		if err == nil {
			glog.Infof("Updated loadbalancer %v", lbID)
			return &response, nil
		} else {
			glog.Errorf("Attemp %d: failed to update loadbalancer %v: %v\n", i, lbID, err)
		}
		time.Sleep(RetryIntervalOnError)
	}
	return nil, fmt.Errorf("Unable to update loadbalancer %v\n", lbID)
}

// waitForLoadBalancerReady waits loadbalancer to be ready.
func (an *Anchnet) waitForLoadBalancerReady(lbID string) error {
	for i := 0; i < RetryCountOnWaitReady; i++ {
		request := anchnet_client.DescribeLoadBalancersRequest{
			LoadbalancerIDs: []string{lbID},
		}
		var response anchnet_client.DescribeLoadBalancersResponse
		err := an.client.SendRequest(request, &response)
		if err == nil {
			if len(response.ItemSet) == 0 {
				glog.Errorf("Attemp %d: received nil error but empty response while getting loadbalancer %v\n", i, lbID)
			} else {
				if response.ItemSet[0].Status == "active" {
					glog.Infof("Loadbalancer %v is ready (active status)\n", lbID)
					return nil
				} else {
					glog.Errorf("Attemp %d: loadbalancer %v not ready yet, current status: %v\n", i, lbID, response.ItemSet[0].Status)
				}
			}
		} else {
			glog.Errorf("Attemp %d: failed to get loadbalancer %v: %v\n", i, lbID, err)
		}
		time.Sleep(RetryIntervalOnWaitReady)
	}
	return fmt.Errorf("Loadbalancer %v is not ready after timeout", lbID)
}
