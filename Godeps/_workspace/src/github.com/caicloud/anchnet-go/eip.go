// Copyright 2015 anchnet-go authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package anchnet

// Implements all anchnet instance related APIs.

type DescribeEipsRequest struct {
	RequestCommon `json:",inline"`
	Eips          []string    `json:"eips,omitempty"`
	Status        []EipStatus `json:"status,omitempty"`
	SearchWord    string      `json:"search_word,omitempty"`
	Offset        int         `json:"offset,omitempty"`
	Limit         int         `json:"limit,omitempty"`
}

type DescribeEipsResponse struct {
	ResponseCommon `json:",inline"`
	TotalCount     int                `json:"total_count,omitempty"`
	ItemSet        []DescribeEipsItem `json:"item_set,omitempty"`
}

type DescribeEipsItem struct {
	Attachon    int                  `json:"attachon,omitempty"`
	Bandwidth   int                  `json:"bandwidth,omitempty"`
	Description string               `json:"description,omitempty"`
	CreateTime  string               `json:"create_time,omitempty"`
	StatusTime  string               `json:"status_time,omitempty"`
	Status      EipStatus            `json:"status,omitempty"`
	NeedIcp     int                  `json:"need_icp,omitempty"`
	EipID       string               `json:"eip_id,omitempty"`
	EipName     string               `json:"eip_name,omitempty"`
	EipAddr     string               `json:"eip_addr,omitempty"`
	Resource    DescribeEipsResource `json:"resource,omitempty"`
	EipGroup    DescribeEipsEipGroup `json:"eip_group,omitempty"`
}

type DescribeEipsResource struct {
	ResourceID   string `json:"resource_id,omitempty"`
	ResourceName string `json:"resource_name,omitempty"`
	ResourceType string `json:"resource_type,omitempty"`
}

type DescribeEipsEipGroup struct {
	EipGroupID   string `json:"eip_group_id,omitempty"`
	EipGroupName string `json:"eip_group_name,omitempty"`
}

type EipStatus string

const (
	EipStatusPending    EipStatus = "pending"
	EipStatusAvailable  EipStatus = "available"
	EipStatusAssociated EipStatus = "associated"
	EipStatusSuspended  EipStatus = "suspended"
)

type AllocateEipsRequest struct {
	RequestCommon `json:",inline"`
	Product       AllocateEipsProduct `json:"product,omitempty"`
}

type AllocateEipsResponse struct {
	ResponseCommon `json:",inline"`
	Eips           []string `json:"eips,omitempty"`
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

type ReleaseEipsRequest struct {
	RequestCommon `json:",inline"`
	Eips          []string `json:"eips,omitempty"`
}

type ReleaseEipsResponse struct {
	ResponseCommon `json:",inline"`
	JobID          string `json:"job_id,omitempty"`
}

type AssociateEipRequest struct {
	RequestCommon `json:",inline"`
	Eip           string `json:"eip,omitempty"`
	Instance      string `json:"instance,omitempty"`
}

type AssociateEipResponse struct {
	ResponseCommon `json:",inline"`
	JobID          string `json:"job_id,omitempty"`
}

type DissociateEipsRequest struct {
	RequestCommon `json:",inline"`
	Eips          []string `json:"eips,omitempty"`
}

type DissociateEipsResponse struct {
	ResponseCommon `json:",inline"`
	JobID          string `json:"job_id,omitempty"`
}

type ChangeEipsBandwidthRequest struct {
	RequestCommon `json:",inline"`
	Eips          []string `json:"eips,omitempty"`
	Bandwidth     int      `json:"bandwidth,omitempty"` // In Mbps
}

type ChangeEipsBandwidthResponse struct {
	ResponseCommon `json:",inline"`
	JobID          string `json:"job_id,omitempty"`
}
