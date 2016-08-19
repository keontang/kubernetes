/*
Copyright 2016 The Kubernetes Authors All rights reserved.

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

package aliyun

import (
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net"
	"os"

	"github.com/denverdino/aliyungo/common"
	"github.com/denverdino/aliyungo/ecs"
	"github.com/denverdino/aliyungo/slb"
	"github.com/golang/glog"
	"k8s.io/kubernetes/pkg/api"
	"k8s.io/kubernetes/pkg/cloudprovider"
	"k8s.io/kubernetes/pkg/types"
	"k8s.io/kubernetes/pkg/util/sets"
)

// getAddressesByName return an instance address slice by it's name.
func (aly *Aliyun) getAddressesByName(name string) ([]api.NodeAddress, error) {
	instance, err := aly.getInstanceByName(name)
	if err != nil {
		glog.Errorf("Error getting instance by name '%s': %v", name, err)
		return nil, err
	}

	addrs := []api.NodeAddress{}

	if len(instance.PublicIpAddress.IpAddress) > 0 {
		for _, ipaddr := range instance.PublicIpAddress.IpAddress {
			addrs = append(addrs, api.NodeAddress{Type: api.NodeExternalIP, Address: ipaddr})
		}
	}

	if instance.EipAddress.IpAddress != "" {
		addrs = append(addrs, api.NodeAddress{Type: api.NodeExternalIP, Address: instance.EipAddress.IpAddress})
	}

	if len(instance.InnerIpAddress.IpAddress) > 0 {
		for _, ipaddr := range instance.InnerIpAddress.IpAddress {
			addrs = append(addrs, api.NodeAddress{Type: api.NodeInternalIP, Address: ipaddr})
		}
	}

	if len(instance.VpcAttributes.PrivateIpAddress.IpAddress) > 0 {
		for _, ipaddr := range instance.VpcAttributes.PrivateIpAddress.IpAddress {
			addrs = append(addrs, api.NodeAddress{Type: api.NodeInternalIP, Address: ipaddr})
		}
	}

	if instance.VpcAttributes.NatIpAddress != "" {
		addrs = append(addrs, api.NodeAddress{Type: api.NodeInternalIP, Address: instance.VpcAttributes.NatIpAddress})
	}

	return addrs, nil
}

func (aly *Aliyun) getInstanceByNameAndStatus(name string, status ecs.InstanceStatus) (*ecs.InstanceAttributesType, error) {
	args := ecs.DescribeInstancesArgs{
		RegionId:     common.Region(aly.regionID),
		InstanceName: name,
		Status:       status,
	}

	instances, _, err := aly.ecsClient.DescribeInstances(&args)
	if err != nil {
		glog.Errorf("Couldn't DescribeInstances(%v): %v", args, err)
		return nil, err
	}

	if len(instances) == 0 {
		return nil, fmt.Errorf("Couldn't get Instances by args '%v'", args)
	}

	return &instances[0], nil
}

func (aly *Aliyun) getInstanceByName(name string) (*ecs.InstanceAttributesType, error) {
	instances, err := aly.getInstancesByNameFilter(name)
	if err != nil {
		glog.Errorf("Error get instances by name_filter '%s': %v", name, err)
		return nil, err
	}

	return &instances[0], nil
}

func (aly *Aliyun) getInstancesByNameFilter(name_filter string) ([]ecs.InstanceAttributesType, error) {
	args := ecs.DescribeInstancesArgs{
		RegionId:     common.Region(aly.regionID),
		InstanceName: name_filter,
	}

	instances, _, err := aly.ecsClient.DescribeInstances(&args)
	if err != nil {
		glog.Errorf("Couldn't DescribeInstances(%v): %v", args, err)
		return nil, err
	}

	if len(instances) == 0 {
		return nil, fmt.Errorf("Couldn't get Instances by args '%v'", args)
	}

	return instances, nil
}

func (aly *Aliyun) getInstanceIdByNameAndStatus(name string, status ecs.InstanceStatus) (string, error) {
	instance, err := aly.getInstanceByNameAndStatus(name, status)
	if err != nil {
		return "", err
	}
	return instance.InstanceId, nil
}

func (aly *Aliyun) getInstanceIdByName(name string) (string, error) {
	instance, err := aly.getInstanceByName(name)
	if err != nil {
		return "", err
	}
	return instance.InstanceId, nil
}

func (aly *Aliyun) createLoadBalancer(name string) (response *slb.CreateLoadBalancerResponse, err error) {
	args := slb.CreateLoadBalancerArgs{
		RegionId:           common.Region(aly.regionID),
		LoadBalancerName:   name,
		AddressType:        aly.lbOpts.AddressType,
		InternetChargeType: aly.lbOpts.InternetChargeType,
		Bandwidth:          aly.lbOpts.Bandwidth,
	}
	response, err = aly.slbClient.CreateLoadBalancer(&args)
	if err != nil {
		glog.Errorf("Couldn't CreateLoadBalancer(%v): %v", args, err)
		return nil, err
	}

	glog.V(4).Infof("CreateLoadBalancer(%v): %v", args, response)

	return response, nil
}

func (aly *Aliyun) deleteLoadBalancer(loadBalancerID string) error {
	return aly.slbClient.DeleteLoadBalancer(loadBalancerID)
}

// Add backend servers to the specified load balancer.
func (aly *Aliyun) addBackendServers(loadbalancerID string, instanceIDs []string) error {
	backendServers := []slb.BackendServerType{}
	for index, instanceID := range instanceIDs {
		backendServers = append(backendServers,
			slb.BackendServerType{
				ServerId: instanceID,
				Weight:   100,
			},
		)

		// For AddBackendServer, The maximum number of elements in backendServers List is 20.
		if index%20 == 19 {
			_, err := aly.slbClient.AddBackendServers(loadbalancerID, backendServers)
			if err != nil {
				glog.Errorf("Couldn't AddBackendServers(%v, %v): %v", loadbalancerID, backendServers, err)
				return err
			}
			backendServers = backendServers[0:0]
		}
	}

	_, err := aly.slbClient.AddBackendServers(loadbalancerID, backendServers)
	if err != nil {
		glog.Errorf("Couldn't AddBackendServers(%v, %v): %v", loadbalancerID, backendServers, err)
		return err
	}

	glog.V(4).Infof("AddBackendServers(%v, %v)", loadbalancerID, backendServers)

	return nil
}

// Remove backend servers from the specified load balancer.
func (aly *Aliyun) removeBackendServers(loadBalancerID string, instanceIDs []string) error {
	_, err := aly.slbClient.RemoveBackendServers(loadBalancerID, instanceIDs)
	if err != nil {
		glog.Errorf("Couldn't RemoveBackendServers(%v, %v): %v", loadBalancerID, instanceIDs, err)
		return err
	}

	return nil
}

func (aly *Aliyun) createLoadBalancerTCPListener(loadBalancerID string, port *api.ServicePort, bandwidth int) error {
	args := slb.CreateLoadBalancerTCPListenerArgs{
		LoadBalancerId:    loadBalancerID,
		ListenerPort:      port.Port,
		BackendServerPort: port.NodePort,
		// Bandwidth peak of Listener Value: -1 | 1 - 1000 Mbps, default is -1.
		Bandwidth: bandwidth,
	}
	return aly.slbClient.CreateLoadBalancerTCPListener(&args)
}

func (aly *Aliyun) createLoadBalancerUDPListener(loadBalancerID string, port *api.ServicePort, bandwidth int) error {
	args := slb.CreateLoadBalancerUDPListenerArgs{
		LoadBalancerId:    loadBalancerID,
		ListenerPort:      port.Port,
		BackendServerPort: port.NodePort,
		Bandwidth:         bandwidth,
	}
	return aly.slbClient.CreateLoadBalancerUDPListener(&args)
}

func (aly *Aliyun) getLoadBalancerByName(name string) (loadbalancer *slb.LoadBalancerType, exists bool, err error) {
	// Find all the loadbalancers in the current region.
	args := slb.DescribeLoadBalancersArgs{
		RegionId: common.Region(aly.regionID),
	}
	loadbalancers, err := aly.slbClient.DescribeLoadBalancers(&args)
	if err != nil {
		glog.Errorf("Couldn't DescribeLoadBalancers(%v): %v", args, err)
		return nil, false, err
	}
	glog.V(4).Infof("getLoadBalancerByName(%s) in region '%s': %v", name, aly.regionID, loadbalancers)

	// Find the specified load balancer with the matching name
	for _, lb := range loadbalancers {
		if lb.LoadBalancerName == name {
			glog.V(4).Infof("Find loadbalancer(%s) in region '%s'", name, aly.regionID)
			return &lb, true, nil
		}
	}

	glog.Infof("Couldn't find loadbalancer by name '%s'", name)

	return nil, false, nil
}

func (aly *Aliyun) getLoadBalancerAttribute(loadBalancerID string) (loadbalancer *slb.LoadBalancerType, err error) {
	loadbalancer, err = aly.slbClient.DescribeLoadBalancerAttribute(loadBalancerID)
	if err != nil {
		glog.Errorf("Couldn't DescribeLoadBalancerAttribute(%s): %v", loadBalancerID, err)
		return nil, err
	}

	return loadbalancer, nil
}

func (aly *Aliyun) setLoadBalancerStatus(loadBalancerID string, status slb.Status) (err error) {
	return aly.slbClient.SetLoadBalancerStatus(loadBalancerID, status)
}
