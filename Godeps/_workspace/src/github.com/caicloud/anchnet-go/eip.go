// Copyright 2015 anchnet-go authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package anchnet

// Implements all anchnet instance related APIs.

//
// DescribeEips retrieves information of a list of eips.
//
type DescribeEipsRequest struct {
	RequestCommon `json:",inline"`
	EipIDs        []string    `json:"eips,omitempty"`
	SearchWord    string      `json:"search_word,omitempty"`
	Status        []EipStatus `json:"status,omitempty"`
	Offset        int         `json:"offset,omitempty"`
	Limit         int         `json:"limit,omitempty"`
}

type DescribeEipsResponse struct {
	ResponseCommon `json:",inline"`
	TotalCount     int                `json:"total_count,omitempty"`
	ItemSet        []DescribeEipsItem `json:"item_set,omitempty"`
}

type DescribeEipsItem struct {
	EipID        string                   `json:"eip_id,omitempty"`
	EipName      string                   `json:"eip_name,omitempty"`
	EipAddr      string                   `json:"eip_addr,omitempty"`
	Attachon     int                      `json:"attachon,omitempty"`
	Bandwidth    int                      `json:"bandwidth,omitempty"`
	Description  string                   `json:"description,omitempty"`
	CreateTime   string                   `json:"create_time,omitempty"`
	StatusTime   string                   `json:"status_time,omitempty"`
	Status       EipStatus                `json:"status,omitempty"`
	NeedIcp      int                      `json:"need_icp,omitempty"`
	Resource     DescribeEipsResource     `json:"resource,omitempty"` // Resource means an instance
	EipGroup     DescribeEipsEipGroup     `json:"eip_group,omitempty"`
	Loadbalancer DescribeEipsLoadbalancer `json:"loadbalancer,omitempty"`
}

type DescribeEipsResource struct {
	ResourceID   string `json:"resource_id,omitempty"`
	ResourceName string `json:"resource_name,omitempty"`
	ResourceType string `json:"resource_type,omitempty"` // Only known value is "instance"
}

type DescribeEipsEipGroup struct {
	EipGroupID   string `json:"eip_group_id,omitempty"`
	EipGroupName string `json:"eip_group_name,omitempty"`
}

type DescribeEipsLoadbalancer struct {
	LoadbalancerID   string `json:"loadbalancer_id,omitempty"`
	LoadbalancerName string `json:"loadbalancer_name,omitempty"`
}

type EipStatus string

const (
	EipStatusPending    EipStatus = "pending"
	EipStatusAvailable  EipStatus = "available"
	EipStatusAssociated EipStatus = "associated"
	EipStatusSuspended  EipStatus = "suspended"
)

//
// AllocateEips creates (allocate) an unused external IP.
//
type AllocateEipsRequest struct {
	RequestCommon `json:",inline"`
	Product       AllocateEipsProduct `json:"product,omitempty"`
}

type AllocateEipsResponse struct {
	ResponseCommon `json:",inline"`
	EipIDs         []string `json:"eips,omitempty"`
	JobID          string   `json:"job_id,omitempty"`
}

type AllocateEipsProduct struct {
	IP AllocateEipsIP `json:"ip,omitempty"`
}

type AllocateEipsIP struct {
	IPGroup   string `json:"ip_group,omitempty"` // Only "eipg-00000000" is BGP for now
	Bandwidth int    `json:"bw,omitempty"`       // In MB/s
	Amount    int    `json:"amount,omitempty"`   // Default 1
}

//
// ReleaseEips deletes (release) a list of external IPs.
//
type ReleaseEipsRequest struct {
	RequestCommon `json:",inline"`
	EipIDs        []string `json:"eips,omitempty"`
}

type ReleaseEipsResponse struct {
	ResponseCommon `json:",inline"`
	JobID          string `json:"job_id,omitempty"`
}

//
// AssociateEip attaches an eip to an instance.
//
type AssociateEipRequest struct {
	RequestCommon `json:",inline"`
	EipID         string `json:"eip,omitempty"`
	InstanceID    string `json:"instance,omitempty"`
}

type AssociateEipResponse struct {
	ResponseCommon `json:",inline"`
	JobID          string `json:"job_id,omitempty"`
}

//
// DisssociateEips detaches a list of eips from their resources.
//
type DissociateEipsRequest struct {
	RequestCommon `json:",inline"`
	EipIDs        []string `json:"eips,omitempty"`
}

type DissociateEipsResponse struct {
	ResponseCommon `json:",inline"`
	JobID          string `json:"job_id,omitempty"`
}

//
// ChangeEipsBandwidth changes bandwith of a list of eips.
//
type ChangeEipsBandwidthRequest struct {
	RequestCommon `json:",inline"`
	EipIDs        []string `json:"eips,omitempty"`
	Bandwidth     int      `json:"bandwidth,omitempty"` // In Mbps
}

type ChangeEipsBandwidthResponse struct {
	ResponseCommon `json:",inline"`
	JobID          string `json:"job_id,omitempty"`
}
