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
	"io/ioutil"
	"net/http"
)

const (
	// Default endpoint.
	DefaultEndpoint string = "http://api.51idc.com/cloud/api/iaas"

	// Default configuration directory (relative to HOME).
	ConfigDir = ".anchnet"

	// Default configuration file.
	ConfigFile = "config"
)

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
	Action string `json:"action,omitempty"`
	Token  string `json:"token,omitempty"`
	Zone   string `json:"zone,omitempty"`
}

// ResponseCommon is the common response from all server responses. RetCode is returned
// for every request but not documented; it is used internally. `mapstructure` tag is
// used for mapstructure pkg to decode into acutal response.
// http://cloud.51idc.com/help/api/public_params.html
type ResponseCommon struct {
	Action  string `json:"action,omitempty" mapstructure:"action"`
	Code    int    `json:"code,omitempty" mapstructure:"code"`
	RetCode int    `json:"ret_code,omitempty mapstructure:"ret_code""`
	Message string `json:"message,omitempty" mapstructure:"message"`
}

// NewClient creates a new client.
func NewClient(endpoint string, auth *AuthConfiguration) (*Client, error) {
	return &Client{
		HTTPClient: http.DefaultClient,
		auth:       auth,
		endpoint:   endpoint,
	}, nil
}

// sendRequest takes json body and send request. The return value is a json response,
// used with mapstructure package to decode into acutal go struct.
func (c *Client) sendRequest(request interface{}) (map[string]interface{}, error) {
	resp, err := c.do(request)
	if err != nil {
		return nil, err
	}

	respBody, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}

	var respJsonBody map[string]interface{}
	err = json.Unmarshal(respBody, &respJsonBody)
	if err != nil {
		return nil, err
	}
	return respJsonBody, nil
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
