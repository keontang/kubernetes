// Copyright 2015 anchnet-go authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package anchnet

import (
	"net/http/httptest"
	"reflect"
	"testing"
)

// TestCreateVxnets tests that we send correct request to create vxnets.
func TestCreateVxnets(t *testing.T) {
	expectedJson := RemoveWhitespaces(`
{
  "action": "CreateVxnets",
  "count": 1,
  "token": "E5I9QKJF1O2B5PXE68LG",
  "vxnet_name": "21",
  "vxnet_type": 0,
  "zone": "ac1"
}
`)

	fakeResponse := RemoveWhitespaces(`
{
  "ret_code": 0,
  "action": "CreateVxnetsResponse",
  "vxnets": [
    "vxnet-9IAPUWZN"
  ],
  "code": 0,
  "job_id": "job-I0HU0S3U"
}
`)

	testServer := httptest.NewServer(&FakeHandler{t: t, ExpectedJson: expectedJson, FakeResponse: fakeResponse})
	defer testServer.Close()

	body := CreateVxnetsRequest{
		VxnetName: "21",
		Count:     1,
		VxnetType: VxnetTypePriv,
	}

	c, err := NewClient(testServer.URL, &AuthConfiguration{PublicKey: "E5I9QKJF1O2B5PXE68LG", PrivateKey: "secret"})
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}
	resp, err := c.CreateVxnets(body)
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}
	if resp == nil {
		t.Errorf("Unexpected nil response")
	}

	expectedResponseBody := &CreateVxnetsResponse{
		ResponseCommon: ResponseCommon{
			Action:  "CreateVxnetsResponse",
			RetCode: 0,
			Code:    0,
		},
		Vxnets: []string{"vxnet-9IAPUWZN"},
		JobID:  "job-I0HU0S3U",
	}
	if !reflect.DeepEqual(expectedResponseBody, resp) {
		t.Errorf("Error: expected \n%v, got \n%v", expectedResponseBody, resp)
	}
}

// TestDeleteVxnets tests that we send correct request to delete vxnets.
func TestDeleteVxnets(t *testing.T) {
	expectedJson := RemoveWhitespaces(`
{
  "action":"DeleteVxnets",
  "token":"E5I9QKJF1O2B5PXE68LG",
  "vxnets":[
    "vxnet-SAUO93R1",
    "vxnet-ABC"
  ],
  "zone":"ac1"
}
`)

	fakeResponse := RemoveWhitespaces(`
{
  "ret_code":0,
  "action":"DeleteVxnetsResponse",
  "code":0,
  "job_id":"job-49QFG05P"
}
`)

	testServer := httptest.NewServer(&FakeHandler{t: t, ExpectedJson: expectedJson, FakeResponse: fakeResponse})
	defer testServer.Close()

	body := DeleteVxnetsRequest{
		Vxnets: []string{"vxnet-SAUO93R1", "vxnet-ABC"},
	}

	c, err := NewClient(testServer.URL, &AuthConfiguration{PublicKey: "E5I9QKJF1O2B5PXE68LG", PrivateKey: "secret"})
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}
	resp, err := c.DeleteVxnets(body)
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}
	if resp == nil {
		t.Errorf("Unexpected nil response")
	}

	expectedResponseBody := &DeleteVxnetsResponse{
		ResponseCommon: ResponseCommon{
			Action:  "DeleteVxnetsResponse",
			RetCode: 0,
			Code:    0,
		},
		JobID: "job-49QFG05P",
	}
	if !reflect.DeepEqual(expectedResponseBody, resp) {
		t.Errorf("Error: expected \n%v, got \n%v", expectedResponseBody, resp)
	}
}

// TestDescribeVxnets tests that we send correct request to describe vxnets.
func TestDescribeVxnets(t *testing.T) {
	expectedJson := RemoveWhitespaces(`
{
  "zone": "ac1",
  "verbose": 1,
  "vxnets": [
    "vxnet-RL0ICH3P"
  ],
  "token": "E5I9QKJF1O2B5PXE68LG",
  "action": "DescribeVxnets"
}
`)

	fakeResponse := RemoveWhitespaces(`
{
  "code": 0,
  "ret_code": 0,
  "action": "DescribeVxnetsResponse",
  "item_set": [
    {
      "vxnet_addr": "",
      "vxnet_id": "vxnet-0",
      "vxnet_name": "test",
      "description": "test_public_vxnet",
      "systype": "pub",
      "vxnet_type": 1,
      "create_time": "",
      "router": [],
      "instances": []
    },
    {
      "vxnet_addr": null,
      "vxnet_id": "vxnet-RL0ICH3P",
      "vxnet_name": "test_again",
      "description": "test_private_vxnet",
      "systype": "priv",
      "vxnet_type": 0,
      "create_time": "2015-03-24",
      "router": [],
      "instances": [
        {
          "instance_id": "i-0ZHRC2DH",
          "instance_name": "we"
        }
      ]
    }
  ]
}
`)

	testServer := httptest.NewServer(&FakeHandler{t: t, ExpectedJson: expectedJson, FakeResponse: fakeResponse})
	defer testServer.Close()

	body := DescribeVxnetsRequest{
		Vxnets:  []string{"vxnet-RL0ICH3P"},
		Verbose: 1,
	}

	c, err := NewClient(testServer.URL, &AuthConfiguration{PublicKey: "E5I9QKJF1O2B5PXE68LG", PrivateKey: "secret"})
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}
	resp, err := c.DescribeVxnets(body)
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}
	if resp == nil {
		t.Errorf("Unexpected nil response")
	}

	expectedResponseBody := &DescribeVxnetsResponse{
		ResponseCommon: ResponseCommon{
			Action:  "DescribeVxnetsResponse",
			RetCode: 0,
			Code:    0,
		},
		ItemSet: []DescribeVxnetsItemSet{
			DescribeVxnetsItemSet{
				VxnetName:   "test",
				VxnetID:     "vxnet-0",
				VxnetAddr:   "",
				Description: "test_public_vxnet",
				Systype:     "pub",
				VxnetType:   VxnetTypePub,
				CreateTime:  "",
				Router:      []DescribeVxnetsRouter{},
				Instances:   []DescribeVxnetsInstance{},
			},
			DescribeVxnetsItemSet{
				VxnetName:   "test_again",
				VxnetID:     "vxnet-RL0ICH3P",
				VxnetAddr:   "",
				Description: "test_private_vxnet",
				Systype:     "priv",
				VxnetType:   VxnetTypePriv,
				CreateTime:  "2015-03-24",
				Router:      []DescribeVxnetsRouter{},
				Instances: []DescribeVxnetsInstance{
					DescribeVxnetsInstance{
						InstanceName: "we",
						InstanceID:   "i-0ZHRC2DH",
					},
				},
			},
		},
	}
	if !reflect.DeepEqual(expectedResponseBody, resp) {
		t.Errorf("Error: expected \n%v, got \n%v", expectedResponseBody, resp)
	}
}

// TestJoinVxnet tests that we send correct request to join vxnets.
func TestJoinVxnet(t *testing.T) {
	expectedJson := RemoveWhitespaces(`
{
  "vxnet":"vxnet-SAUD093R1",
  "token":"E5I9QKJF1O2B5PXE68LG",
  "instances":[
    "i-RDARAR8K"
  ],
  "action":"JoinVxnet",
  "zone":"ac1"
}
`)

	fakeResponse := RemoveWhitespaces(`
{
  "ret_code":0,
  "action":"JoinVxnetResponse",
  "code":0,
  "job_id":"job-NIAMZENR"
}
`)

	testServer := httptest.NewServer(&FakeHandler{t: t, ExpectedJson: expectedJson, FakeResponse: fakeResponse})
	defer testServer.Close()

	body := JoinVxnetRequest{
		Vxnet:     "vxnet-SAUD093R1",
		Instances: []string{"i-RDARAR8K"},
	}

	c, err := NewClient(testServer.URL, &AuthConfiguration{PublicKey: "E5I9QKJF1O2B5PXE68LG", PrivateKey: "secret"})
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}
	resp, err := c.JoinVxnet(body)
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}
	if resp == nil {
		t.Errorf("Unexpected nil response")
	}

	expectedResponseBody := &JoinVxnetResponse{
		ResponseCommon: ResponseCommon{
			Action:  "JoinVxnetResponse",
			RetCode: 0,
			Code:    0,
		},
		JobID: "job-NIAMZENR",
	}
	if !reflect.DeepEqual(expectedResponseBody, resp) {
		t.Errorf("Error: expected \n%v, got \n%v", expectedResponseBody, resp)
	}
}

// TestLeaveVxnet tests that we send correct request to leave vxnets.
func TestLeaveVxnet(t *testing.T) {
	expectedJson := RemoveWhitespaces(`
{
  "vxnet":"vxnet-SAUD093R1",
  "token":"E5I9QKJF1O2B5PXE68LG",
  "instances":[
    "i-RDARAR8K"
  ],
  "action":"LeaveVxnet",
  "zone":"ac1"
}
`)

	fakeResponse := RemoveWhitespaces(`
{
  "ret_code":0,
  "action":"LeaveVxnetResponse",
  "code":0,
  "job_id":"job-NIAMZENR"
}
`)

	testServer := httptest.NewServer(&FakeHandler{t: t, ExpectedJson: expectedJson, FakeResponse: fakeResponse})
	defer testServer.Close()

	body := LeaveVxnetRequest{
		Vxnet:     "vxnet-SAUD093R1",
		Instances: []string{"i-RDARAR8K"},
	}

	c, err := NewClient(testServer.URL, &AuthConfiguration{PublicKey: "E5I9QKJF1O2B5PXE68LG", PrivateKey: "secret"})
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}
	resp, err := c.LeaveVxnet(body)
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}
	if resp == nil {
		t.Errorf("Unexpected nil response")
	}

	expectedResponseBody := &LeaveVxnetResponse{
		ResponseCommon: ResponseCommon{
			Action:  "LeaveVxnetResponse",
			RetCode: 0,
			Code:    0,
		},
		JobID: "job-NIAMZENR",
	}
	if !reflect.DeepEqual(expectedResponseBody, resp) {
		t.Errorf("Error: expected \n%v, got \n%v", expectedResponseBody, resp)
	}
}
