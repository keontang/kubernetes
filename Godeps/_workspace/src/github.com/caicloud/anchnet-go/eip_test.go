// Copyright 2015 anchnet-go authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package anchnet

import (
	"net/http/httptest"
	"reflect"
	"testing"
)

// TestDescribeEips tests that we send correct request to describe eips.
func TestDescribeEips(t *testing.T) {
	expectedJson := RemoveWhitespaces(`
{
  "limit": 10,
  "token": "E5I9QKJF1O2B5PXE68LG",
  "status": ["pending", "available", "associated", "suspended" ],
	"eips":["eip-L6I69DSQ"],
  "zone":"ac1",
  "action":"DescribeEips"
}
`)

	fakeResponse := RemoveWhitespaces(`
{
  "ret_code":0,
  "action":"DescribeEipsResponse",
  "item_set":[{
    "attachon":644347,
    "bandwidth":1,
    "groupid":602206,
    "eip_addr":"103.21.116.223",
    "eip_id":"eip-L6I69DSQ",
    "eip_name":"103.21.116.223",
    "need_icp":0,
    "description":"",
    "status":"associated",
    "status_time":"2015-02-27-12:58:41",
    "create_time":"2015-02-27-12:52:37",
    "eip_group":{
      "eip_group_id":"eipg-00000000",
      "eip_group_name":"BGP multi-line"
    },
    "resource":{
      "resource_id":"i-7QAQCZ2E",
      "resource_name":"bobo",
      "resource_type":"instance"
    }}],
  "code":0,
  "total_count":1
}
`)

	testServer := httptest.NewServer(&FakeHandler{t: t, ExpectedJson: expectedJson, FakeResponse: fakeResponse})
	defer testServer.Close()

	c, err := NewClient(testServer.URL, &AuthConfiguration{PublicKey: "E5I9QKJF1O2B5PXE68LG", PrivateKey: "secret"})
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}

	request := DescribeEipsRequest{
		Eips:   []string{"eip-L6I69DSQ"},
		Limit:  10,
		Offset: 0,
		Status: []EipStatus{EipStatusPending, EipStatusAvailable, EipStatusAssociated, EipStatusSuspended},
	}
	var response DescribeEipsResponse

	err = c.SendRequest(request, &response)
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}

	expectedResponse := DescribeEipsResponse{
		ResponseCommon: ResponseCommon{
			Action:  "DescribeEipsResponse",
			RetCode: 0,
			Code:    0,
		},
		TotalCount: 1,
		ItemSet: []DescribeEipsItem{
			{
				Attachon:    644347,
				Bandwidth:   1,
				EipAddr:     "103.21.116.223",
				EipID:       "eip-L6I69DSQ",
				EipName:     "103.21.116.223",
				NeedIcp:     0,
				Description: "",
				Status:      EipStatusAssociated,
				StatusTime:  "2015-02-27-12:58:41",
				CreateTime:  "2015-02-27-12:52:37",
				EipGroup: DescribeEipsEipGroup{
					EipGroupID:   "eipg-00000000",
					EipGroupName: "BGPmulti-line",
				},
				Resource: DescribeEipsResource{
					ResourceID:   "i-7QAQCZ2E",
					ResourceName: "bobo",
					ResourceType: "instance",
				},
			},
		},
	}
	if !reflect.DeepEqual(expectedResponse, response) {
		t.Errorf("Error: expected \n%v, got \n%v", expectedResponse, response)
	}
}

// TestAllocateEips tests that we send correct request to allocate eips.
func TestAllocateEips(t *testing.T) {
	expectedJson := RemoveWhitespaces(`
{
  "product":{
    "ip":{
      "bw":1,
      "ip_group":"eipg-00000000",
      "amount":1
    }
  },
  "zone":"ac1",
  "token":"E5I9QKJF1O2B5PXE68LG",
  "action":"AllocateEips"
}
`)

	fakeResponse := RemoveWhitespaces(`
{
  "ret_code":0,
  "action":"AllocateEipsResponse",
  "code":0,
  "eips":[
    "eip-BMTMKDBT"
  ],
  "job_id":"job-ZS1ZZVFF"
}
`)

	testServer := httptest.NewServer(&FakeHandler{t: t, ExpectedJson: expectedJson, FakeResponse: fakeResponse})
	defer testServer.Close()

	c, err := NewClient(testServer.URL, &AuthConfiguration{PublicKey: "E5I9QKJF1O2B5PXE68LG", PrivateKey: "secret"})
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}

	request := AllocateEipsRequest{
		Product: AllocateEipsProduct{
			IP: AllocateEipsIP{
				IPGroup:   "eipg-00000000",
				Bandwidth: 1,
				Amount:    1,
			},
		},
	}
	var response AllocateEipsResponse

	err = c.SendRequest(request, &response)
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}

	expectedResponse := AllocateEipsResponse{
		ResponseCommon: ResponseCommon{
			Action:  "AllocateEipsResponse",
			RetCode: 0,
			Code:    0,
		},
		Eips:  []string{"eip-BMTMKDBT"},
		JobID: "job-ZS1ZZVFF",
	}
	if !reflect.DeepEqual(expectedResponse, response) {
		t.Errorf("Error: expected \n%v, got \n%v", expectedResponse, response)
	}
}

// TestReleaseEips tests that we send correct request to release eips.
func TestReleaseEips(t *testing.T) {
	expectedJson := RemoveWhitespaces(`
{
  "action":"ReleaseEips",
  "eips":[
    "eip-FSYW6I4Q"
  ],
  "zone":"ac1",
  "token":"E5I9QKJF1O2B5PXE68LG"
}
`)

	fakeResponse := RemoveWhitespaces(`
{
  "ret_code":0,
  "action":"ReleaseEipsResponse",
  "code":0,
  "job_id":"job-MDCSSUTN"
}
`)

	testServer := httptest.NewServer(&FakeHandler{t: t, ExpectedJson: expectedJson, FakeResponse: fakeResponse})
	defer testServer.Close()

	c, err := NewClient(testServer.URL, &AuthConfiguration{PublicKey: "E5I9QKJF1O2B5PXE68LG", PrivateKey: "secret"})
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}

	request := ReleaseEipsRequest{
		Eips: []string{"eip-FSYW6I4Q"},
	}
	var response ReleaseEipsResponse

	err = c.SendRequest(request, &response)
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}

	expectedResponse := ReleaseEipsResponse{
		ResponseCommon: ResponseCommon{
			Action:  "ReleaseEipsResponse",
			RetCode: 0,
			Code:    0,
		},
		JobID: "job-MDCSSUTN",
	}
	if !reflect.DeepEqual(expectedResponse, response) {
		t.Errorf("Error: expected \n%v, got \n%v", expectedResponse, response)
	}
}

// TestAssociateEip tests that we send correct request to associate eip.
func TestAssociateEip(t *testing.T) {
	expectedJson := RemoveWhitespaces(`
{
  "action": "AssociateEip",
  "eip": "eip-BMTMKDBT",
  "instance": "i-7QAQCZ2E",
  "token": "E5I9QKJF1O2B5PXE68LG",
  "zone": "ac1"
}
`)

	fakeResponse := RemoveWhitespaces(`
{
  "ret_code": 0,
  "action": "AssociateEipResponse",
  "code": 0,
  "job_id": "job-SW9VWLTA"
}
`)

	testServer := httptest.NewServer(&FakeHandler{t: t, ExpectedJson: expectedJson, FakeResponse: fakeResponse})
	defer testServer.Close()

	c, err := NewClient(testServer.URL, &AuthConfiguration{PublicKey: "E5I9QKJF1O2B5PXE68LG", PrivateKey: "secret"})
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}

	request := AssociateEipRequest{
		Eip:      "eip-BMTMKDBT",
		Instance: "i-7QAQCZ2E",
	}
	var response AssociateEipResponse

	err = c.SendRequest(request, &response)
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}

	expectedResponse := AssociateEipResponse{
		ResponseCommon: ResponseCommon{
			Action:  "AssociateEipResponse",
			RetCode: 0,
			Code:    0,
		},
		JobID: "job-SW9VWLTA",
	}
	if !reflect.DeepEqual(expectedResponse, response) {
		t.Errorf("Error: expected \n%v, got \n%v", expectedResponse, response)
	}
}

// TestDissociateEips tests that we send correct request to dissociate eips.
func TestDissociateEips(t *testing.T) {
	expectedJson := RemoveWhitespaces(`
{
  "action":"DissociateEips",
  "eips":[
    "eip-FSYW6I4Q"
  ],
  "zone":"ac1",
  "token":"E5I9QKJF1O2B5PXE68LG"
}
`)

	fakeResponse := RemoveWhitespaces(`
{
  "ret_code":0,
  "action":"DissociateEipsResponse",
  "code":0,
  "job_id":"job-MDCSSUTN"
}
`)

	testServer := httptest.NewServer(&FakeHandler{t: t, ExpectedJson: expectedJson, FakeResponse: fakeResponse})
	defer testServer.Close()

	c, err := NewClient(testServer.URL, &AuthConfiguration{PublicKey: "E5I9QKJF1O2B5PXE68LG", PrivateKey: "secret"})
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}

	request := DissociateEipsRequest{
		Eips: []string{"eip-FSYW6I4Q"},
	}
	var response DissociateEipsResponse

	err = c.SendRequest(request, &response)
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}

	expectedResponse := DissociateEipsResponse{
		ResponseCommon: ResponseCommon{
			Action:  "DissociateEipsResponse",
			RetCode: 0,
			Code:    0,
		},
		JobID: "job-MDCSSUTN",
	}
	if !reflect.DeepEqual(expectedResponse, response) {
		t.Errorf("Error: expected \n%v, got \n%v", expectedResponse, response)
	}
}

// TestChangeEipsBandwidth tests that we send correct request to change eips bandwidth.
func TestChangeEipsBandwidth(t *testing.T) {
	expectedJson := RemoveWhitespaces(`
{
  "eips": ["eip-L6I69DSQ"],
  "bandwidth": 2,
  "action": "ChangeEipsBandwidth ",
  "token": "E5I9QKJF1O2B5PXE68LG",
  "zone": "ac1"
}
`)

	fakeResponse := RemoveWhitespaces(`
{
  "ret_code":0,
  "action":"ChangeEipsBandwidthResponse",
  "code":0,
  "job_id":"job-C6G7X4WD"
}
`)

	testServer := httptest.NewServer(&FakeHandler{t: t, ExpectedJson: expectedJson, FakeResponse: fakeResponse})
	defer testServer.Close()

	c, err := NewClient(testServer.URL, &AuthConfiguration{PublicKey: "E5I9QKJF1O2B5PXE68LG", PrivateKey: "secret"})
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}

	request := ChangeEipsBandwidthRequest{
		Eips:      []string{"eip-L6I69DSQ"},
		Bandwidth: 2,
	}
	var response ChangeEipsBandwidthResponse

	err = c.SendRequest(request, &response)
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}

	expectedResponse := ChangeEipsBandwidthResponse{
		ResponseCommon: ResponseCommon{
			Action:  "ChangeEipsBandwidthResponse",
			RetCode: 0,
			Code:    0,
		},
		JobID: "job-C6G7X4WD",
	}
	if !reflect.DeepEqual(expectedResponse, response) {
		t.Errorf("Error: expected \n%v, got \n%v", expectedResponse, response)
	}
}
