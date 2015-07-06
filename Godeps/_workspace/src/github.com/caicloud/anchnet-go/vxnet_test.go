// Copyright 2015 anchnet-go authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package anchnet

import (
	"net/http/httptest"
	"reflect"
	"testing"
)

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

	c, err := NewClient(testServer.URL, &AuthConfiguration{PublicKey: "E5I9QKJF1O2B5PXE68LG", PrivateKey: "secret"})
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}

	request := DescribeVxnetsRequest{
		Vxnets:  []string{"vxnet-RL0ICH3P"},
		Verbose: 1,
	}
	var response DescribeVxnetsResponse

	err = c.SendRequest(request, &response)
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}

	expectedResponse := DescribeVxnetsResponse{
		ResponseCommon: ResponseCommon{
			Action:  "DescribeVxnetsResponse",
			RetCode: 0,
			Code:    0,
		},
		ItemSet: []DescribeVxnetsItem{
			{
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
			{
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
	if !reflect.DeepEqual(expectedResponse, response) {
		t.Errorf("Error: expected \n%v, got \n%v", expectedResponse, response)
	}
}

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

	c, err := NewClient(testServer.URL, &AuthConfiguration{PublicKey: "E5I9QKJF1O2B5PXE68LG", PrivateKey: "secret"})
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}

	request := CreateVxnetsRequest{
		VxnetName: "21",
		Count:     1,
		VxnetType: VxnetTypePriv,
	}
	var response CreateVxnetsResponse

	err = c.SendRequest(request, &response)
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}

	expectedResponse := CreateVxnetsResponse{
		ResponseCommon: ResponseCommon{
			Action:  "CreateVxnetsResponse",
			RetCode: 0,
			Code:    0,
		},
		Vxnets: []string{"vxnet-9IAPUWZN"},
		JobID:  "job-I0HU0S3U",
	}
	if !reflect.DeepEqual(expectedResponse, response) {
		t.Errorf("Error: expected \n%v, got \n%v", expectedResponse, response)
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

	c, err := NewClient(testServer.URL, &AuthConfiguration{PublicKey: "E5I9QKJF1O2B5PXE68LG", PrivateKey: "secret"})
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}

	request := DeleteVxnetsRequest{
		Vxnets: []string{"vxnet-SAUO93R1", "vxnet-ABC"},
	}
	var response DeleteVxnetsResponse

	err = c.SendRequest(request, &response)
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}

	expectedResponse := DeleteVxnetsResponse{
		ResponseCommon: ResponseCommon{
			Action:  "DeleteVxnetsResponse",
			RetCode: 0,
			Code:    0,
		},
		JobID: "job-49QFG05P",
	}
	if !reflect.DeepEqual(expectedResponse, response) {
		t.Errorf("Error: expected \n%v, got \n%v", expectedResponse, response)
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

	c, err := NewClient(testServer.URL, &AuthConfiguration{PublicKey: "E5I9QKJF1O2B5PXE68LG", PrivateKey: "secret"})
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}

	request := JoinVxnetRequest{
		Vxnet:     "vxnet-SAUD093R1",
		Instances: []string{"i-RDARAR8K"},
	}
	var response JoinVxnetResponse

	err = c.SendRequest(request, &response)
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}

	expectedResponse := JoinVxnetResponse{
		ResponseCommon: ResponseCommon{
			Action:  "JoinVxnetResponse",
			RetCode: 0,
			Code:    0,
		},
		JobID: "job-NIAMZENR",
	}
	if !reflect.DeepEqual(expectedResponse, response) {
		t.Errorf("Error: expected \n%v, got \n%v", expectedResponse, response)
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

	c, err := NewClient(testServer.URL, &AuthConfiguration{PublicKey: "E5I9QKJF1O2B5PXE68LG", PrivateKey: "secret"})
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}

	request := LeaveVxnetRequest{
		Vxnet:     "vxnet-SAUD093R1",
		Instances: []string{"i-RDARAR8K"},
	}
	var response LeaveVxnetResponse

	err = c.SendRequest(request, &response)
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}

	expectedResponse := LeaveVxnetResponse{
		ResponseCommon: ResponseCommon{
			Action:  "LeaveVxnetResponse",
			RetCode: 0,
			Code:    0,
		},
		JobID: "job-NIAMZENR",
	}
	if !reflect.DeepEqual(expectedResponse, response) {
		t.Errorf("Error: expected \n%v, got \n%v", expectedResponse, response)
	}
}

// TestModifyVxnetAttributes tests that we send correct request to modify vxnet attributes.
func TestModifyVxnetAttributes(t *testing.T) {
	expectedJson := RemoveWhitespaces(`
{
  "action":"ModifyVxnetAttributes",
  "description":"51idc",
  "token":"E5I9QKJF1O2B5PXE68LG",
  "vxnet":"vxnet-SAUO93R1",
  "vxnet_name":"yuyu",
  "zone":"ac1"
}
`)

	fakeResponse := RemoveWhitespaces(`
{
  "ret_code":0,
  "action":"ModifyVxnetAttributesResponse",
  "code":0,
  "vxnet_id":"vxnet-SAUO93R1",
  "job_id":"job-FF6S8QRZ"
}
`)

	testServer := httptest.NewServer(&FakeHandler{t: t, ExpectedJson: expectedJson, FakeResponse: fakeResponse})
	defer testServer.Close()

	c, err := NewClient(testServer.URL, &AuthConfiguration{PublicKey: "E5I9QKJF1O2B5PXE68LG", PrivateKey: "secret"})
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}

	request := ModifyVxnetAttributesRequest{
		Vxnet:       "vxnet-SAUO93R1",
		VxnetName:   "yuyu",
		Description: "51idc",
	}
	var response ModifyVxnetAttributesResponse

	err = c.SendRequest(request, &response)
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}

	expectedResponse := ModifyVxnetAttributesResponse{
		ResponseCommon: ResponseCommon{
			Action:  "ModifyVxnetAttributesResponse",
			RetCode: 0,
			Code:    0,
		},
		JobID: "job-FF6S8QRZ",
	}
	if !reflect.DeepEqual(expectedResponse, response) {
		t.Errorf("Error: expected \n%v, got \n%v", expectedResponse, response)
	}
}
