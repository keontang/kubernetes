// Copyright 2015 anchnet-go authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package anchnet

import (
	"github.com/caicloud/anchnet-go/vendor/_nuts/github.com/mitchellh/mapstructure"
)

type CreateLoadBalancerProduct struct {
	// FW contains id for firewall
	FW CreateLoadBalancerFW `json:"fw,omitempty"`

	// LB contains information about load balancer
	LB CreateLoadBalancerLB `json:"lb,omitempty"`

	// IP contains information about public IP
	IP []CreateLoadBalancerIP `json:"ip,omitempty"`
}

type CreateLoadBalancerFW struct {
	Ref string `json:"ref,omitempty"` // id of the firewall
}

type CreateLoadBalancerLB struct {
	Name string `json:"name,omitempty"` // name of the lb
	Type int    `json:"type,omitempty"` // maximum connections. Choices:1(20k), 2(40k), 3(100k)
}

type CreateLoadBalancerIP struct {
	Ref string `json:"ref,omitempty"` // ids of public ips that load balancer will bind to
}

// CreateLoadBalancerRequest contains all information needed to create a load balancer
type CreateLoadBalancerRequest struct {
	RequestCommon `json:",inline"`
	Product       CreateLoadBalancerProduct `json:"product,omitempty"`
}

// CreateLoadBalancerResponse contains all information returned from server
type CreateLoadBalancerResponse struct {
	ResponseCommon `json:",inline" mapstructure:",squash"`
	JobID          string `json:"job_id,omitempty" mapstructure:"job_id"`                   // job id in anchnet
	LBID           string `json:"loadbalancer_id,omitempty" mapstructure:"loadbalancer_id"` // load balancer id
}

// CreateLoadBalancer creates a load balancer. One load balancer can bind to multiple public IPs
func (c *Client) CreateLoadBalancer(request CreateLoadBalancerRequest) (*CreateLoadBalancerResponse, error) {
	request.RequestCommon.Token = c.auth.PublicKey
	request.RequestCommon.Action = "CreateLoadBalancer"
	request.RequestCommon.Zone = "ac1" // Only one zone for now

	resp, err := c.sendRequest(request)
	if err != nil {
		return nil, err
	}

	var result CreateLoadBalancerResponse
	err = mapstructure.Decode(resp, &result)
	if err != nil {
		return nil, err
	}

	return &result, nil
}
