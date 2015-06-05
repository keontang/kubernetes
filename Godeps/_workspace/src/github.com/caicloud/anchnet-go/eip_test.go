// Copyright 2015 anchnet-go authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package anchnet

import (
	"net/http/httptest"
	"reflect"
	"testing"
)

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

	body := AllocateEipsRequest{
		Product: AllocateEipsProduct{
			IPs: AllocateEipsIP{
				IPGroup:   "eipg-00000000",
				Bandwidth: 1,
				Amount:    1,
			},
		},
	}

	c, err := NewClient(testServer.URL, &AuthConfiguration{PublicKey: "E5I9QKJF1O2B5PXE68LG", PrivateKey: "secret"})
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}
	resp, err := c.AllocateEips(body)
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}
	if resp == nil {
		t.Errorf("Unexpected nil response")
	}

	expectedResponseBody := &AllocateEipsResponse{
		ResponseCommon: ResponseCommon{
			Action:  "AllocateEipsResponse",
			RetCode: 0,
			Code:    0,
		},
		Eips:  []string{"eip-BMTMKDBT"},
		JobID: "job-ZS1ZZVFF",
	}
	if !reflect.DeepEqual(expectedResponseBody, resp) {
		t.Errorf("Error: expected \n%v, got \n%v", expectedResponseBody, resp)
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

	body := ReleaseEipsRequest{
		Eips: []string{"eip-FSYW6I4Q"},
	}

	c, err := NewClient(testServer.URL, &AuthConfiguration{PublicKey: "E5I9QKJF1O2B5PXE68LG", PrivateKey: "secret"})
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}
	resp, err := c.ReleaseEips(body)
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}
	if resp == nil {
		t.Errorf("Unexpected nil response")
	}

	expectedResponseBody := &ReleaseEipsResponse{
		ResponseCommon: ResponseCommon{
			Action:  "ReleaseEipsResponse",
			RetCode: 0,
			Code:    0,
		},
		JobID: "job-MDCSSUTN",
	}
	if !reflect.DeepEqual(expectedResponseBody, resp) {
		t.Errorf("Error: expected \n%v, got \n%v", expectedResponseBody, resp)
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

	body := AssociateEipRequest{
		Eip:      "eip-BMTMKDBT",
		Instance: "i-7QAQCZ2E",
	}

	c, err := NewClient(testServer.URL, &AuthConfiguration{PublicKey: "E5I9QKJF1O2B5PXE68LG", PrivateKey: "secret"})
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}
	resp, err := c.AssociateEip(body)
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}
	if resp == nil {
		t.Errorf("Unexpected nil response")
	}

	expectedResponseBody := &AssociateEipResponse{
		ResponseCommon: ResponseCommon{
			Action:  "AssociateEipResponse",
			RetCode: 0,
			Code:    0,
		},
		JobID: "job-SW9VWLTA",
	}
	if !reflect.DeepEqual(expectedResponseBody, resp) {
		t.Errorf("Error: expected \n%v, got \n%v", expectedResponseBody, resp)
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

	body := DissociateEipsRequest{
		Eips: []string{"eip-FSYW6I4Q"},
	}

	c, err := NewClient(testServer.URL, &AuthConfiguration{PublicKey: "E5I9QKJF1O2B5PXE68LG", PrivateKey: "secret"})
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}
	resp, err := c.DissociateEips(body)
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}
	if resp == nil {
		t.Errorf("Unexpected nil response")
	}

	expectedResponseBody := &DissociateEipsResponse{
		ResponseCommon: ResponseCommon{
			Action:  "DissociateEipsResponse",
			RetCode: 0,
			Code:    0,
		},
		JobID: "job-MDCSSUTN",
	}
	if !reflect.DeepEqual(expectedResponseBody, resp) {
		t.Errorf("Error: expected \n%v, got \n%v", expectedResponseBody, resp)
	}
}

// TestDescribeEips tests that we send correct request to describe eips.
func TestDescribeEips(t *testing.T) {
	expectedJson := RemoveWhitespaces(`
{
  "limit": 10,
  "offset": 0,
  "token": "E5I9QKJF1O2B5PXE68LG",
  "status": ["pending", "available", "associated", "suspended" ],
	"eips":["eip-L6I69DSQ"],
	"search_word":"",
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

	body := DescribeEipsRequest{
		Eips:   []string{"eip-L6I69DSQ"},
		Limit:  10,
		Offset: 0,
		Status: []string{"pending", "available", "associated", "suspended"},
	}

	c, err := NewClient(testServer.URL, &AuthConfiguration{PublicKey: "E5I9QKJF1O2B5PXE68LG", PrivateKey: "secret"})
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}
	resp, err := c.DescribeEips(body)
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}
	if resp == nil {
		t.Errorf("Unexpected nil response")
	}

	expectedResponseBody := &DescribeEipsResponse{
		ResponseCommon: ResponseCommon{
			Action:  "DescribeEipsResponse",
			RetCode: 0,
			Code:    0,
		},
		TotalCount: 1,
		ItemSet: []DescribeEipsItemSet{
			DescribeEipsItemSet{
				Attachon:    644347,
				Bandwidth:   1,
				EipAddr:     "103.21.116.223",
				EipID:       "eip-L6I69DSQ",
				EipName:     "103.21.116.223",
				NeedIcp:     0,
				Description: "",
				Status:      "associated",
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
	if !reflect.DeepEqual(expectedResponseBody, resp) {
		t.Errorf("Error: expected \n%v, got \n%v", expectedResponseBody, resp)
	}
}
