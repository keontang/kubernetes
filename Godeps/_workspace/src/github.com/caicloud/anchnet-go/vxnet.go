// Copyright 2015 anchnet-go authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package anchnet

// Implements all anchnet vxnet related APIs.

//
// DescribeVxnets retrieves information of a list of vxnets.
//
type DescribeVxnetsRequest struct {
	RequestCommon `json:",inline"`
	VxnetIDs      []string `json:"vxnets,omitempty"` // IDs of network to describe
	Verbose       int      `json:"verbose,omitempty"`
}

type DescribeVxnetsResponse struct {
	ResponseCommon `json:",inline"`
	ItemSet        []DescribeVxnetsItem `json:"item_set,omitempty"`
}

type DescribeVxnetsItem struct {
	VxnetID     string                   `json:"vxnet_id,omitempty"`
	VxnetName   string                   `json:"vxnet_name,omitempty"`
	VxnetAddr   string                   `json:"vxnet_addr,omitempty"`
	VxnetType   VxnetType                `json:"vxnet_type"` // Do not omit empty due to type 0
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

//
// CreateVxnets creates given number of vxnet. Note anchnet doesn't mention creating
// public network, so even though there is a VxnetType, currently we should only use
// private network.
//
type CreateVxnetsRequest struct {
	RequestCommon `json:",inline"`
	VxnetName     string    `json:"vxnet_name,omitempty"`
	VxnetType     VxnetType `json:"vxnet_type"`      // Type of new network. Do not omity empty due to type 0
	Count         int       `json:"count,omitempty"` // Number of network to create, default to 1
}

type CreateVxnetsResponse struct {
	ResponseCommon `json:",inline"`
	JobID          string   `json:"job_id,omitempty"`
	VxnetIDs       []string `json:"vxnets,omitempty"` // IDs of created networks
}

// VxnetType is the type of SDN network: public or private.
type VxnetType int

const (
	VxnetTypePriv VxnetType = 0
	VxnetTypePub  VxnetType = 1
)

//
// DeleteVxnets deletes a list of vxnet.
//
type DeleteVxnetsRequest struct {
	RequestCommon `json:",inline"`
	VxnetIDs      []string `json:"vxnets,omitempty"` // IDs of networks to delete
}

type DeleteVxnetsResponse struct {
	ResponseCommon `json:",inline"`
	JobID          string `json:"job_id,omitempty"`
}

//
// JoinVxnet attaches a list of instances to a vxnet.
//
type JoinVxnetRequest struct {
	RequestCommon `json:",inline"`
	InstanceIDs   []string `json:"instances,omitempty"` // IDs of instances to join
	VxnetID       string   `json:"vxnet,omitempty"`     // ID of the network to join to
}

type JoinVxnetResponse struct {
	ResponseCommon `json:",inline"`
	JobID          string `json:"job_id,omitempty"`
}

//
// LeaveVxnet deataches a list of instances from a vxnet.
//
type LeaveVxnetRequest struct {
	RequestCommon `json:",inline"`
	InstanceIDs   []string `json:"instances,omitempty"` // IDs of instances to leave
	VxnetID       string   `json:"vxnet,omitempty"`     // ID of the network to leave from
}

type LeaveVxnetResponse struct {
	ResponseCommon `json:",inline"`
	JobID          string `json:"job_id,omitempty"`
}

//
// ModifyVxnetAttributesRequest modifies attributes of a vxnet.
//
type ModifyVxnetAttributesRequest struct {
	RequestCommon `json:",inline"`
	VxnetID       string `json:"vxnet,omitempty"`
	VxnetName     string `json:"vxnet_name,omitempty"`
	Description   string `json:"description,omitempty"`
}

type ModifyVxnetAttributesResponse struct {
	ResponseCommon `json:",inline"`
	JobID          string `json:"job_id,omitempty"`
}
