// Copyright 2015 anchnet-go authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package anchnet

// Implements all anchnet vxnet related APIs.

type DescribeVxnetsRequest struct {
	RequestCommon `json:",inline"`
	Vxnets        []string `json:"vxnets,omitempty"` // IDs of network to describe
	Verbose       int      `json:"verbose,omitempty"`
}

type DescribeVxnetsResponse struct {
	ResponseCommon `json:",inline"`
	ItemSet        []DescribeVxnetsItem `json:"item_set,omitempty"`
}

type DescribeVxnetsItem struct {
	VxnetName string `json:"vxnet_name,omitempty"`
	VxnetID   string `json:"vxnet_id,omitempty"`
	VxnetAddr string `json:"vxnet_addr,omitempty"`
	// Do not omit empty due to type 0.
	VxnetType   VxnetType                `json:"vxnet_type"`
	Systype     string                   `json:"systype,omitempty"`
	Description string                   `json:"description,omitempty"`
	CreateTime  string                   `json:"create_time,omitempty"`
	Router      []DescribeVxnetsRouter   `json:"router,omitempty"`
	Instances   []DescribeVxnetsInstance `json:"instances,omitempty"`
}

type DescribeVxnetsRouter struct{}

type DescribeVxnetsInstance struct {
	InstanceID   string `json:"instance_id,omitempty"`
	InstanceName string `json:"instance_name,omitempty"`
}

type CreateVxnetsRequest struct {
	RequestCommon `json:",inline"`
	VxnetName     string `json:"vxnet_name,omitempty"`
	// Do not omity empty due to type 0.
	VxnetType VxnetType `json:"vxnet_type"`      // Type of new network. 0 is private (anchnet doesn't mention public)
	Count     int       `json:"count,omitempty"` // Number of network to create, default to 1
}

type CreateVxnetsResponse struct {
	ResponseCommon `json:",inline"`
	JobID          string   `json:"job_id,omitempty"`
	Vxnets         []string `json:"vxnets,omitempty"` // IDs of created networks
}

// VxnetType is the type of SDN network: public or private.
type VxnetType int

const (
	VxnetTypePriv VxnetType = 0
	VxnetTypePub  VxnetType = 1
)

type DeleteVxnetsRequest struct {
	RequestCommon `json:",inline"`
	Vxnets        []string `json:"vxnets,omitempty"` // IDs of networks to delete
}

type DeleteVxnetsResponse struct {
	ResponseCommon `json:",inline"`
	JobID          string `json:"job_id,omitempty"`
}

type JoinVxnetRequest struct {
	RequestCommon `json:",inline"`
	Instances     []string `json:"instances,omitempty"` // IDs of instances to join
	Vxnet         string   `json:"vxnet,omitempty"`     // ID of the network to join to
}

type JoinVxnetResponse struct {
	ResponseCommon `json:",inline"`
	JobID          string `json:"job_id,omitempty"`
}

type LeaveVxnetRequest struct {
	RequestCommon `json:",inline"`
	Instances     []string `json:"instances,omitempty"` // IDs of instances to leave
	Vxnet         string   `json:"vxnet,omitempty"`     // ID of the network to leave from
}

type LeaveVxnetResponse struct {
	ResponseCommon `json:",inline"`
	JobID          string `json:"job_id,omitempty"`
}

type ModifyVxnetAttributesRequest struct {
	RequestCommon `json:",inline"`
	Vxnet         string `json:"vxnet,omitempty"`
	VxnetName     string `json:"vxnet_name,omitempty"`
	Description   string `json:"description,omitempty"`
}

type ModifyVxnetAttributesResponse struct {
	ResponseCommon `json:",inline"`
	JobID          string `json:"job_id,omitempty"`
}
