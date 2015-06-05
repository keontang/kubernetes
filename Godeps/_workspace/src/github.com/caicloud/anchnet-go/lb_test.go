// Copyright 2015 anchnet-go authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package anchnet

import (
	"net/http/httptest"
	"reflect"
	"testing"
)

// TestCreateLoadBalancer tests that we send correct request to create load balancer.
func TestCreateLoadBalancer(t *testing.T) {
	expectedJson := RemoveWhitespaces(`
{
  "product": {
    "fw": {
      "ref": "sg-EFBL5JC2"
    },
    "lb": {
      "name": "wang_test",
      "type": 1
    },
    "ip":[
      {
        "ref": "eip-2WA55DIC"
      }
    ]
  },
  "token":  "E5I9QKJF1O2B5PXE68LG",
  "action": "CreateLoadBalancer",
  "zone":   "ac1"
}
`)

	fakeResponse := RemoveWhitespaces(`
{
  "ret_code": 0,
  "loadbalancer_id": "lb-XU9DCS95",
  "action": "CreateLoadBalancerResponse",
  "code": 0,
  "job_id": "job-MO0OBCMY"
}
`)

	testServer := httptest.NewServer(&FakeHandler{t: t, ExpectedJson: expectedJson, FakeResponse: fakeResponse})
	defer testServer.Close()

	body := CreateLoadBalancerRequest{
		Product: CreateLoadBalancerProduct{
			FW: CreateLoadBalancerFW{
				Ref: "sg-EFBL5JC2",
			},
			LB: CreateLoadBalancerLB{
				Name: "wang_test",
				Type: 1,
			},
			IP: []CreateLoadBalancerIP{
				{
					Ref: "eip-2WA55DIC",
				},
			},
		},
	}

	c, err := NewClient(testServer.URL, &AuthConfiguration{PublicKey: "E5I9QKJF1O2B5PXE68LG", PrivateKey: "secret"})
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}
	resp, err := c.CreateLoadBalancer(body)
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}
	if resp == nil {
		t.Errorf("Unexpected nil response")
	}

	expectedResponseBody := &CreateLoadBalancerResponse{
		ResponseCommon: ResponseCommon{
			Action:  "CreateLoadBalancerResponse",
			RetCode: 0,
			Code:    0,
		},
		LBID:  "lb-XU9DCS95",
		JobID: "job-MO0OBCMY",
	}
	if !reflect.DeepEqual(expectedResponseBody, resp) {
		t.Errorf("Error: expected \n%v, got \n%v", expectedResponseBody, resp)
	}
}
