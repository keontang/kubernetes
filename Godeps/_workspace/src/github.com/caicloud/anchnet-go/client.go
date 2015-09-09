// Copyright 2015 anchnet-go authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// Package anchnet provides go client for anchnet cloud. Document:
// http://cloud.51idc.com/help/api/overview.html
// First class resources in anchnet:
// - Instance: a virtual machine. Example instance id: i-DCFA40VV
// - Volume: a hard disk or SSD, can be attached to an instance. Example volume id: vol-46Q60KA1
// - External IP (EIP): external IP address, can be attached to an instance. Example eip id: eip-TYFJDV7K
// - SDN network: a public or private network connecting multiple instances. When creaing instance with eip,
//   a default public SDN network (usually with id vxnet-0) is used. Example SDN network id: vxnet-OXC1RD7G
// Note there are rooms for refactoring the APIs, but anchnet's API
// is inheriently inconsistent, so it's better to keep the redundant
// code. We'll leave the refactor to the future.
package anchnet

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"net/http"
	"reflect"
	"strings"
)

const (
	// Default endpoint.
	DefaultEndpoint string = "http://api.51idc.com/cloud/api/iaas"

	// Default configuration directory (relative to HOME).
	ConfigDir = ".anchnet"
	// Default configuration file.
	ConfigFile = "config"
)

// All registered actions.
var actions = make(map[string]bool)

func init() {
	actions["DescribeInstances"] = true
	actions["RunInstances"] = true
	actions["TerminateInstances"] = true
	actions["StartInstances"] = true
	actions["StopInstances"] = true
	actions["RestartInstances"] = true
	actions["ResetLoginPasswd"] = true
	actions["ModifyInstanceAttributes"] = true

	actions["DescribeEips"] = true
	actions["AllocateEips"] = true
	actions["ReleaseEips"] = true
	actions["AssociateEip"] = true
	actions["DissociateEips"] = true
	actions["ChangeEipsBandwidth"] = true

	actions["DescribeVxnets"] = true
	actions["CreateVxnets"] = true
	actions["DeleteVxnets"] = true
	actions["JoinVxnet"] = true
	actions["LeaveVxnet"] = true
	actions["ModifyVxnetAttributes"] = true

	actions["DescribeVolumes"] = true
	actions["CreateVolumes"] = true
	actions["DeleteVolumes"] = true
	actions["AttachVolumes"] = true
	actions["DetachVolumes"] = true
	actions["ResizeVolumes"] = true
	actions["ModifyVolumeAttributes"] = true

	actions["DescribeLoadBalancers"] = true
	actions["CreateLoadBalancer"] = true
	actions["DeleteLoadBalancers"] = true
	actions["StartLoadBalancer"] = true
	actions["StopLoadBalancer"] = true
	actions["ModifyLoadBalancerAttributes"] = true
	actions["UpdateLoadBalancers"] = true
	actions["ResizeLoadBalancers"] = true
	actions["AssociateEipsToLoadBalancer"] = true
	actions["DissociateEipsFromLoadBalancer"] = true
	actions["AddLoadBalancerListeners"] = true
	actions["DeleteLoadBalancerListeners"] = true
	actions["DescribeLoadBalancerListeners"] = true
	actions["ModifyLoadBalancerListenerAttributes"] = true
	actions["AddLoadBalancerBackends"] = true
	actions["DeleteLoadBalancerBackends"] = true
	actions["DescribeLoadBalancerBackends"] = true
	actions["ModifyLoadBalancerBackendAttributes"] = true

	actions["DescribeSecurityGroups"] = true
	actions["CreateSecurityGroup"] = true
	actions["DeleteSecurityGroups"] = true
	actions["ApplySecurityGroup"] = true
	actions["ModifySecurityGroupAttributes"] = true
	actions["DescribeSecurityGroupRules"] = true
	actions["AddSecurityGroupRules"] = true
	actions["DeleteSecurityGroupRules"] = true
	actions["ModifySecurityGroupRuleAttributes"] = true

	actions["DescribeJobs"] = true

	actions["CreateUserProject"] = true
	actions["DescribeProjects"] = true
	actions["Transfer"] = true
}

// Client represents an anchnet client.
type Client struct {
	HTTPClient *http.Client

	auth     *AuthConfiguration
	endpoint string
}

// RequestCommon is the common request options used in all requests. Unless strictly
// necessary, client doesn't need to specify these. Action will be set per different
// API, e.g. RunInstances, Token will be set by API method using auth.PublicKey, Zone
// is set to "ac1" which is the only zone supported.
// http://cloud.51idc.com/help/api/public_params.html
type RequestCommon struct {
	Action  string `json:"action,omitempty"`
	Token   string `json:"token,omitempty"`
	Zone    string `json:"zone,omitempty"`
	Project string `json:"project,omitempty"`
}

// ResponseCommon is the common response from all server responses. RetCode is returned
// for every request but not documented; it is used internally (internal representation
// of value Code).
// http://cloud.51idc.com/help/api/public_params.html
type ResponseCommon struct {
	Action  string `json:"action,omitempty"`
	Code    int    `json:"code"` // Do not omit empty since code=0 means no error.
	RetCode int    `json:"ret_code,omitempty"`
	Message string `json:"message,omitempty"`
}

// NewClient creates a new client.
func NewClient(endpoint string, auth *AuthConfiguration) (*Client, error) {
	return &Client{
		HTTPClient: http.DefaultClient,
		auth:       auth,
		endpoint:   endpoint,
	}, nil
}

// SendRequest sends request to anchnet and returns response. 'response' must be
// a pointer value.
func (c *Client) SendRequest(request interface{}, response interface{}) error {
	if reflect.TypeOf(response).Kind() != reflect.Ptr {
		return fmt.Errorf("expected pointer arg for response")
	}

	// Make a copy of request so that we are able to set common fields.
	dst, err := Deepcopy(request)
	if err != nil {
		return err
	}

	// Set request common parameters. Note 'ac1' is the only supported zone, so we set it here.
	v := reflect.ValueOf(dst).Elem()
	v.FieldByName("RequestCommon").FieldByName("Token").SetString(c.auth.PublicKey)
	v.FieldByName("RequestCommon").FieldByName("Project").SetString(c.auth.ProjectId)
	v.FieldByName("RequestCommon").FieldByName("Zone").SetString("ac1")
	t := reflect.TypeOf(request).String()
	found := false
	for action := range actions {
		// Type name contains action, e.g. anchnet.DescribeInstancesRequest contains DescribeInstances.
		if strings.Contains(t, action) {
			v.FieldByName("RequestCommon").FieldByName("Action").SetString(action)
			found = true
			break
		}
	}
	if found == false {
		return fmt.Errorf("Unknown request type: %v", t)
	}

	// Send actual request.
	resp, err := c.do(dst)
	if err != nil {
		return err
	}

	// Read response and unmarshal it.
	respBody, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		return err
	}

	err = json.Unmarshal(respBody, response)
	if err != nil {
		return err
	}

	// Determine error code and set error response accordingly.
	vv := reflect.ValueOf(response).Elem()
	code := vv.FieldByName("ResponseCommon").FieldByName("Code").Int()
	if code != 0 {
		message := vv.FieldByName("ResponseCommon").FieldByName("Message").String()
		return fmt.Errorf("Server returns error code %v: %s", code, message)
	}

	return nil
}

func (c *Client) do(data interface{}) (resp *http.Response, err error) {
	buf, err := json.Marshal(data)
	if err != nil {
		return nil, err
	}

	// All anchnet request uses POST.
	req, err := http.NewRequest("POST", c.endpoint, bytes.NewBuffer(buf))
	if err != nil {
		return nil, err
	}

	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("signature", GenSignature(buf, []byte(c.auth.PrivateKey)))

	return c.HTTPClient.Do(req)
}
