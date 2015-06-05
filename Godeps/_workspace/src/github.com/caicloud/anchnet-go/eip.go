// Copyright 2015 anchnet-go authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package anchnet

import (
	"github.com/caicloud/anchnet-go/vendor/_nuts/github.com/mitchellh/mapstructure"
)

// Implements all anchnet instance related APIs. [x] means done, [ ] means not done yet.
//   [x] DescribeEips
//   [x] AllocateEips
//   [x] ReleaseEips
//   [x] AssociateEip
//   [x] DissociateEips
//   [ ] ChangeEipsBandwidth

type DescribeEipsRequest struct {
	RequestCommon `json:",inline"`
	Eips          []string `json:"eips,omitempty" mapstructure:"eips"`
	Status        []string `json:"status,omitempty"`
	SearchWord    string   `json:"search_word,omitemtpy"`
	Offset        int      `json:"offset,omitemtpy"`
	Limit         int      `json:"limit,omitemtpy"`
}

type DescribeEipsResponse struct {
	ResponseCommon `json:",inline" mapstructure:",squash"`
	TotalCount     int                   `json:"total_count,omitemtpy" mapstructure:"total_count"`
	ItemSet        []DescribeEipsItemSet `json:"item_set,omitemtpy" mapstructure:"item_set"`
}

type DescribeEipsItemSet struct {
	Attachon    int                  `json:"attachon" mapstructure:"attachon"`
	Bandwidth   int                  `json:"bandwidth" mapstructure:"bandwidth"`
	Description string               `json:"description" mapstructure:"description"`
	CreateTime  string               `json:"create_time" mapstructure:"create_time"`
	StatusTime  string               `json:"status_time" mapstructure:"status_time"`
	Status      string               `json:"status" mapstructure:"status"` // One of "pending", ”available”, ”associated”, ”suspended”
	NeedIcp     int                  `json:"need_icp" mapstructure:"need_icp"`
	EipID       string               `json:"eip_id" mapstructure:"eip_id"`
	EipName     string               `json:"eip_name" mapstructure:"eip_name"`
	EipAddr     string               `json:"eip_addr" mapstructure:"eip_addr"`
	Resource    DescribeEipsResource `json:"resource" mapstructure:"resource"`
	EipGroup    DescribeEipsEipGroup `json:"eip_group" mapstructure:"eip_group"`
}

type DescribeEipsResource struct {
	ResourceID   string `json:"resource_id" mapstructure:"resource_id"`
	ResourceName string `json:"resource_name" mapstructure:"resource_name"`
	ResourceType string `json:"resource_type" mapstructure:"resource_type"`
}

type DescribeEipsEipGroup struct {
	EipGroupID   string `json:"eip_group_id" mapstructure:"eip_group_id"`
	EipGroupName string `json:"eip_group_name" mapstructure:"eip_group_name"`
}

// DescribeEips describes external IPs.
// http://cloud.51idc.com/help/api/eip/DescribeEips.html
func (c *Client) DescribeEips(request DescribeEipsRequest) (*DescribeEipsResponse, error) {
	request.RequestCommon.Token = c.auth.PublicKey
	request.RequestCommon.Action = "DescribeEips"
	request.RequestCommon.Zone = "ac1" // Only one zone for now
	resp, err := c.sendRequest(request)
	if err != nil {
		return nil, err
	}

	var result DescribeEipsResponse
	err = mapstructure.Decode(resp, &result)
	if err != nil {
		return nil, err
	}

	return &result, nil
}

type AllocateEipsProduct struct {
	IPs AllocateEipsIP `json:"ip,omitempty"`
}

type AllocateEipsIP struct {
	IPGroup   string `json:"ip_group,omitempty"` // Only "eipg-00000000" is BGP for now
	Bandwidth int    `json:"bw,omitempty"`       // In MB/s
	Amount    int    `json:"amount,omitempty"`   // Default 1
}

type AllocateEipsRequest struct {
	RequestCommon `json:",inline"`
	Product       AllocateEipsProduct `json:"product,omitempty"`
}

type AllocateEipsResponse struct {
	ResponseCommon `json:",inline" mapstructure:",squash"`
	Eips           []string `json:"eips,omitempty" mapstructure:"eips"`
	JobID          string   `json:"job_id,omitempty" mapstructure:"job_id"`
}

// AllocateEips allocates external IPs.
// http://cloud.51idc.com/help/api/eip/AllocateEips.html
func (c *Client) AllocateEips(request AllocateEipsRequest) (*AllocateEipsResponse, error) {
	request.RequestCommon.Token = c.auth.PublicKey
	request.RequestCommon.Action = "AllocateEips"
	request.RequestCommon.Zone = "ac1" // Only one zone for now
	resp, err := c.sendRequest(request)
	if err != nil {
		return nil, err
	}

	var result AllocateEipsResponse
	err = mapstructure.Decode(resp, &result)
	if err != nil {
		return nil, err
	}

	return &result, nil
}

type ReleaseEipsRequest struct {
	RequestCommon `json:",inline"`
	Eips          []string `json:"eips,omitempty"`
}

type ReleaseEipsResponse struct {
	ResponseCommon `json:",inline" mapstructure:",squash"`
	JobID          string `json:"job_id,omitempty" mapstructure:"job_id"`
}

// ReleaseEips releases external IPs. The external IPs will be dissociated with
// instance or LB before being released.
// http://cloud.51idc.com/help/api/eip/ReleaseEips.html
func (c *Client) ReleaseEips(request ReleaseEipsRequest) (*ReleaseEipsResponse, error) {
	request.RequestCommon.Token = c.auth.PublicKey
	request.RequestCommon.Action = "ReleaseEips"
	request.RequestCommon.Zone = "ac1" // Only one zone for now
	resp, err := c.sendRequest(request)
	if err != nil {
		return nil, err
	}

	var result ReleaseEipsResponse
	err = mapstructure.Decode(resp, &result)
	if err != nil {
		return nil, err
	}

	return &result, nil
}

type AssociateEipRequest struct {
	RequestCommon `json:",inline"`
	Eip           string `json:"eip,omitempty"`
	Instance      string `json:"instance,omitempty"`
}

type AssociateEipResponse struct {
	ResponseCommon `json:",inline" mapstructure:",squash"`
	JobID          string `json:"job_id,omitempty" mapstructure:"job_id"`
}

// AssociateEip associates external IP with an instance
// http://cloud.51idc.com/help/api/eip/AssociateEip.html
func (c *Client) AssociateEip(request AssociateEipRequest) (*AssociateEipResponse, error) {
	request.RequestCommon.Token = c.auth.PublicKey
	request.RequestCommon.Action = "AssociateEip"
	request.RequestCommon.Zone = "ac1" // Only one zone for now
	resp, err := c.sendRequest(request)
	if err != nil {
		return nil, err
	}

	var result AssociateEipResponse
	err = mapstructure.Decode(resp, &result)
	if err != nil {
		return nil, err
	}

	return &result, nil
}

type DissociateEipsRequest struct {
	RequestCommon `json:",inline"`
	Eips          []string `json:"eips,omitempty"`
}

type DissociateEipsResponse struct {
	ResponseCommon `json:",inline" mapstructure:",squash"`
	JobID          string `json:"job_id,omitempty" mapstructure:"job_id"`
}

// DissociateEips dissociates external IPs.
// http://cloud.51idc.com/help/api/eip/DissociateEips.html
func (c *Client) DissociateEips(request DissociateEipsRequest) (*DissociateEipsResponse, error) {
	request.RequestCommon.Token = c.auth.PublicKey
	request.RequestCommon.Action = "DissociateEips"
	request.RequestCommon.Zone = "ac1" // Only one zone for now
	resp, err := c.sendRequest(request)
	if err != nil {
		return nil, err
	}

	var result DissociateEipsResponse
	err = mapstructure.Decode(resp, &result)
	if err != nil {
		return nil, err
	}

	return &result, nil
}
