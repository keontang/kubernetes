// Copyright 2015 anchnet-go authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package anchnet

import (
	"github.com/caicloud/anchnet-go/vendor/_nuts/github.com/mitchellh/mapstructure"
)

// Implements all anchnet vxnet related APIs. [x] means done, [ ] means not done yet.
//   [x] DescribeVxnets
//   [x] CreateVxnets
//   [x] DeleteVxnets
//   [x] JoinVxnet
//   [x] LeaveVxnet
//   [ ] ModifyVxnetAttributes

type VxnetType int

const (
	VxnetTypePriv VxnetType = 0
	VxnetTypePub  VxnetType = 1
)

type CreateVxnetsRequest struct {
	RequestCommon `json:",inline"`
	VxnetName     string    `json:"vxnet_name,omitempty"`
	VxnetType     VxnetType `json:"vxnet_type"`      // Type of new network. 0 is private (anchnet doesn't mention public) Do not omity empty due to type 0
	Count         int       `json:"count,omitempty"` // Number of network to create, default to 1
}

type CreateVxnetsResponse struct {
	ResponseCommon `json:",inline" mapstructure:",squash"`
	JobID          string   `json:"job_id,omitempty" mapstructure:"job_id"`
	Vxnets         []string `json:"vxnets,omitempty" mapstructure:"vxnets"` // IDs of created networks
}

// CreateVxnets creates new SDN networks, typically private network.
// http://cloud.51idc.com/help/api/network/CreateVxnets.html
func (c *Client) CreateVxnets(request CreateVxnetsRequest) (*CreateVxnetsResponse, error) {
	request.RequestCommon.Token = c.auth.PublicKey
	request.RequestCommon.Action = "CreateVxnets"
	request.RequestCommon.Zone = "ac1" // Only one zone for now
	resp, err := c.sendRequest(request)
	if err != nil {
		return nil, err
	}

	var result CreateVxnetsResponse
	err = mapstructure.Decode(resp, &result)
	if err != nil {
		return nil, err
	}

	return &result, nil
}

type DeleteVxnetsRequest struct {
	RequestCommon `json:",inline"`
	Vxnets        []string `json:"vxnets,omitempty"` // IDs of networks to delete
}

type DeleteVxnetsResponse struct {
	ResponseCommon `json:",inline" mapstructure:",squash"`
	JobID          string `json:"job_id,omitempty" mapstructure:"job_id"`
}

// DeleteVxnets deletes given SDN networks. If there are existing instances in the
// network, the instance will be detached before the network is deleted.
// http://cloud.51idc.com/help/api/network/DeleteVxnets.html
func (c *Client) DeleteVxnets(request DeleteVxnetsRequest) (*DeleteVxnetsResponse, error) {
	request.RequestCommon.Token = c.auth.PublicKey
	request.RequestCommon.Action = "DeleteVxnets"
	request.RequestCommon.Zone = "ac1" // Only one zone for now
	resp, err := c.sendRequest(request)
	if err != nil {
		return nil, err
	}

	var result DeleteVxnetsResponse
	err = mapstructure.Decode(resp, &result)
	if err != nil {
		return nil, err
	}

	return &result, nil
}

type DescribeVxnetsRequest struct {
	RequestCommon `json:",inline"`
	Vxnets        []string `json:"vxnets,omitempty"` // IDs of network to describe
	Verbose       int      `json:"verbose,omitempty"`
}

type DescribeVxnetsResponse struct {
	ResponseCommon `json:",inline" mapstructure:",squash"`
	ItemSet        []DescribeVxnetsItemSet `json:"item_set,omitempty" mapstructure:"item_set"`
}

type DescribeVxnetsItemSet struct {
	VxnetName   string                   `json:"vxnet_name,omitempty" mapstructure:"vxnet_name"`
	VxnetID     string                   `json:"vxnet_id,omitempty" mapstructure:"vxnet_id"`
	VxnetAddr   string                   `json:"vxnet_addr,omitempty" mapstructure:"vxnet_addr"`
	VxnetType   VxnetType                `json:"vxnet_type" mapstructure:"vxnet_type"` // Do not omit empty due to type 0
	Systype     string                   `json:"systype,omitempty" mapstructure:"systype"`
	Description string                   `json:"description,omitempty" mapstructure:"description"`
	CreateTime  string                   `json:"create_time,omitempty" mapstructure:"create_time"`
	Router      []DescribeVxnetsRouter   `json:"router,omitempty" mapstructure:"router"`
	Instances   []DescribeVxnetsInstance `json:"instances,omitempty" mapstructure:"instances"`
}

type DescribeVxnetsRouter struct {
}

type DescribeVxnetsInstance struct {
	InstanceID   string `json:"instance_id,omitempty" mapstructure:"instance_id"`
	InstanceName string `json:"instance_name,omitempty" mapstructure:"instance_name"`
}

// DescribeVxnets describes given SDN networks. If there are existing instances in the
// network, the instance will be detached before the network is described.
// http://cloud.51idc.com/help/api/network/DescribeVxnets.html
func (c *Client) DescribeVxnets(request DescribeVxnetsRequest) (*DescribeVxnetsResponse, error) {
	request.RequestCommon.Token = c.auth.PublicKey
	request.RequestCommon.Action = "DescribeVxnets"
	request.RequestCommon.Zone = "ac1" // Only one zone for now
	resp, err := c.sendRequest(request)
	if err != nil {
		return nil, err
	}

	var result DescribeVxnetsResponse
	err = mapstructure.Decode(resp, &result)
	if err != nil {
		return nil, err
	}

	return &result, nil
}

type JoinVxnetRequest struct {
	RequestCommon `json:",inline"`
	Instances     []string `json:"instances,omitempty"` // IDs of instances to join
	Vxnet         string   `json:"vxnet,omitempty"`     // ID of the network to join to
}

type JoinVxnetResponse struct {
	ResponseCommon `json:",inline" mapstructure:",squash"`
	JobID          string `json:"job_id,omitempty" mapstructure:"job_id"`
}

// JoinVxnet joins instances to given SDN network
// http://cloud.51idc.com/help/api/network/Joinvxnet.html
func (c *Client) JoinVxnet(request JoinVxnetRequest) (*JoinVxnetResponse, error) {
	request.RequestCommon.Token = c.auth.PublicKey
	request.RequestCommon.Action = "JoinVxnet"
	request.RequestCommon.Zone = "ac1" // Only one zone for now
	resp, err := c.sendRequest(request)
	if err != nil {
		return nil, err
	}

	var result JoinVxnetResponse
	err = mapstructure.Decode(resp, &result)
	if err != nil {
		return nil, err
	}

	return &result, nil
}

type LeaveVxnetRequest struct {
	RequestCommon `json:",inline"`
	Instances     []string `json:"instances,omitempty"` // IDs of instances to leave
	Vxnet         string   `json:"vxnet,omitempty"`     // ID of the network to leave from
}

type LeaveVxnetResponse struct {
	ResponseCommon `json:",inline" mapstructure:",squash"`
	JobID          string `json:"job_id,omitempty" mapstructure:"job_id"`
}

// LeaveVxnet leaves instances from given SDN networks.
// http://cloud.51idc.com/help/api/network/Leavevxnet.html
func (c *Client) LeaveVxnet(request LeaveVxnetRequest) (*LeaveVxnetResponse, error) {
	request.RequestCommon.Token = c.auth.PublicKey
	request.RequestCommon.Action = "LeaveVxnet"
	request.RequestCommon.Zone = "ac1" // Only one zone for now
	resp, err := c.sendRequest(request)
	if err != nil {
		return nil, err
	}

	var result LeaveVxnetResponse
	err = mapstructure.Decode(resp, &result)
	if err != nil {
		return nil, err
	}

	return &result, nil
}
