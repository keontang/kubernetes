// Copyright 2015 anchnet-go authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package anchnet

import (
	"net/http/httptest"
	"reflect"
	"testing"
)

// TestDescribeSecurityGroups tests that we send correct request to describe security group.
func TestDescribeSecurityGroups(t *testing.T) {
	expectedJson := RemoveWhitespaces(`
{
  "limit": 10,
  "token": "E5I9QKJF1O2B5PXE68LG",
  "verbose": 1,
  "action": "DescribeSecurityGroups",
  "zone": "ac1"
}
`)

	fakeResponse := RemoveWhitespaces(`
{
  "ret_code": 0,
  "action": "DescribeSecurityGroupsResponse",
  "item_set": [
    {
      "is_applied": 0,
      "is_default": 1,
      "security_group_id": "sg-BP4N974S",
      "security_group_name": "default",
      "description": "51idc",
      "create_time": "2015-03-05 10:19:53",
      "rule": [
        {
          "action": "accept",
          "direction": 0,
          "disabled": 1,
          "security_group_rule_id": "sgr-0TZ05IH5",
          "security_group_rule_name": "ping",
          "priority": 1,
          "protocol": "icmp",
          "val1": "8",
          "val2": "0",
          "val3": ""
        },
        {
          "action": "accept",
          "direction": 0,
          "disabled": 0,
          "security_group_rule_id": "sgr-JD71KRWM",
          "security_group_rule_name": "mstsc",
          "priority": 3,
          "protocol": "tcp",
          "val1": "3389",
          "val2": "3389",
          "val3": ""
        },
        {
          "action": "accept",
          "direction": 0,
          "disabled": 0,
          "security_group_rule_id": "sgr-1ZZJJETH",
          "security_group_rule_name": "ssh",
          "priority": 2,
          "protocol": "tcp",
          "val1": "22",
          "val2": "22",
          "val3": ""
        },
        {
          "action": "accept",
          "direction": 0,
          "disabled": 0,
          "security_group_rule_id": "sgr-UBL3EQPJ",
          "security_group_rule_name": "http",
          "priority": 3,
          "protocol": "tcp",
          "val1": "80",
          "val2": "80",
          "val3": ""
        }
      ],
      "resource": []
    }
  ],
  "code": 0,
  "total_count": 1
}
`)

	testServer := httptest.NewServer(&FakeHandler{t: t, ExpectedJson: expectedJson, FakeResponse: fakeResponse})
	defer testServer.Close()

	c, err := NewClient(testServer.URL, &AuthConfiguration{PublicKey: "E5I9QKJF1O2B5PXE68LG", PrivateKey: "secret"})
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}

	request := DescribeSecurityGroupsRequest{
		Verbose: 1,
		Limit:   10,
		Offset:  0,
	}
	var response DescribeSecurityGroupsResponse

	err = c.SendRequest(request, &response)
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}

	expectedResponse := DescribeSecurityGroupsResponse{
		ResponseCommon: ResponseCommon{
			Action:  "DescribeSecurityGroupsResponse",
			RetCode: 0,
			Code:    0,
		},
		TotalCount: 1,
		ItemSet: []DescribeSecurityGroupsItem{
			{
				IsApplied:         0,
				IsDefault:         1,
				SecurityGroupID:   "sg-BP4N974S",
				SecurityGroupName: "default",
				Description:       "51idc",
				CreateTime:        "2015-03-0510:19:53",
				SecurityGroupRules: []DescribeSecurityGroupRule{
					{
						SecurityGroupRuleID:   "sgr-0TZ05IH5",
						SecurityGroupRuleName: "ping",
						Priority:              1,
						Disabled:              1,
						Action:                SecurityGroupRuleActionAccept,
						Direction:             SecurityGroupRuleDirectionDown,
						Protocol:              SecurityGroupRuleProtocolICMP,
						Value1:                "8",
						Value2:                "0",
					},
					{
						SecurityGroupRuleID:   "sgr-JD71KRWM",
						SecurityGroupRuleName: "mstsc",
						Priority:              3,
						Disabled:              0,
						Action:                SecurityGroupRuleActionAccept,
						Direction:             SecurityGroupRuleDirectionDown,
						Protocol:              SecurityGroupRuleProtocolTCP,
						Value1:                "3389",
						Value2:                "3389",
					},
					{
						SecurityGroupRuleID:   "sgr-1ZZJJETH",
						SecurityGroupRuleName: "ssh",
						Priority:              2,
						Disabled:              0,
						Action:                SecurityGroupRuleActionAccept,
						Direction:             SecurityGroupRuleDirectionDown,
						Protocol:              SecurityGroupRuleProtocolTCP,
						Value1:                "22",
						Value2:                "22",
					},
					{
						SecurityGroupRuleID:   "sgr-UBL3EQPJ",
						SecurityGroupRuleName: "http",
						Priority:              3,
						Disabled:              0,
						Action:                SecurityGroupRuleActionAccept,
						Direction:             SecurityGroupRuleDirectionDown,
						Protocol:              SecurityGroupRuleProtocolTCP,
						Value1:                "80",
						Value2:                "80",
					},
				},
			},
		},
	}
	if !reflect.DeepEqual(expectedResponse, response) {
		t.Errorf("Error: expected \n%+v, got \n%+v", expectedResponse, response)
	}
}

// TestCreateSecurityGroup tests that we send correct request to create security group.
func TestCreateSecurityGroup(t *testing.T) {
	expectedJson := RemoveWhitespaces(`
{
  "token": "E5I9QKJF1O2B5PXE68LG",
  "security_group_name": "wang",
  "rule": [
    {
      "protocol": "tcp",
      "security_group_rule_name": "ssh",
      "action": "accept",
      "direction": 0
    }
  ],
  "action": "CreateSecurityGroup",
  "zone": "ac1"
}
`)

	fakeResponse := RemoveWhitespaces(`
{
  "ret_code": 0,
  "security_group_id": "sg-EFBL5JC2",
  "action": "CreateSecurityGroupResponse",
  "code": 0,
  "job_id": "job-K3D66ZCG"
}
`)

	testServer := httptest.NewServer(&FakeHandler{t: t, ExpectedJson: expectedJson, FakeResponse: fakeResponse})
	defer testServer.Close()

	c, err := NewClient(testServer.URL, &AuthConfiguration{PublicKey: "E5I9QKJF1O2B5PXE68LG", PrivateKey: "secret"})
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}

	request := CreateSecurityGroupRequest{
		SecurityGroupName: "wang",
		SecurityGroupRules: []CreateSecurityGroupRule{
			{
				SecurityGroupRuleName: "ssh",
				Disabled:              0,
				Protocol:              SecurityGroupRuleProtocolTCP,
				Direction:             SecurityGroupRuleDirectionDown,
				Action:                SecurityGroupRuleActionAccept,
			},
		},
	}
	var response CreateSecurityGroupResponse

	err = c.SendRequest(request, &response)
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}

	expectedResponse := CreateSecurityGroupResponse{
		ResponseCommon: ResponseCommon{
			Action:  "CreateSecurityGroupResponse",
			RetCode: 0,
			Code:    0,
		},
		SecurityGroupID: "sg-EFBL5JC2",
		JobID:           "job-K3D66ZCG",
	}
	if !reflect.DeepEqual(expectedResponse, response) {
		t.Errorf("Error: expected \n%v, got \n%v", expectedResponse, response)
	}
}

// TestDeleteSecurityGroups tests that we send correct request to delete security groups.
func TestDeleteSecurityGroups(t *testing.T) {
	expectedJson := RemoveWhitespaces(`
{
  "token": "E5I9QKJF1O2B5PXE68LG",
  "action": "DeleteSecurityGroups",
  "zone": "ac1",
  "security_groups": [
    "sg-37820O7J"
  ]
}
`)

	fakeResponse := RemoveWhitespaces(`
{
  "ret_code": 0,
  "action": "DeleteSecurityGroupsResponse",
  "code": 0,
  "job_id": "job-ZZLVMGG3"
}
`)

	testServer := httptest.NewServer(&FakeHandler{t: t, ExpectedJson: expectedJson, FakeResponse: fakeResponse})
	defer testServer.Close()

	c, err := NewClient(testServer.URL, &AuthConfiguration{PublicKey: "E5I9QKJF1O2B5PXE68LG", PrivateKey: "secret"})
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}

	request := DeleteSecurityGroupsRequest{
		SecurityGroupIDs: []string{"sg-37820O7J"},
	}
	var response DeleteSecurityGroupsResponse

	err = c.SendRequest(request, &response)
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}

	expectedResponse := DeleteSecurityGroupsResponse{
		ResponseCommon: ResponseCommon{
			Action:  "DeleteSecurityGroupsResponse",
			RetCode: 0,
			Code:    0,
		},
		JobID: "job-ZZLVMGG3",
	}
	if !reflect.DeepEqual(expectedResponse, response) {
		t.Errorf("Error: expected \n%v, got \n%v", expectedResponse, response)
	}
}

// TestApplySecurityGroup tests that we send correct request to apply security groups.
func TestApplySecurityGroup(t *testing.T) {
	expectedJson := RemoveWhitespaces(`
{
  "security_group": "sg-D3T3CONW",
  "token": "E5I9QKJF1O2B5PXE68LG",
  "action": "ApplySecurityGroup",
  "instances": [
    "i-BX08FEXR",
    "i-C4U0F77C"
  ],
  "zone": "ac1"
}
`)

	fakeResponse := RemoveWhitespaces(`
{
  "ret_code": 0,
  "action": "ApplySecurityGroupResponse",
  "code": 0,
  "job_id": "job-V6XF47A0"
}
`)

	testServer := httptest.NewServer(&FakeHandler{t: t, ExpectedJson: expectedJson, FakeResponse: fakeResponse})
	defer testServer.Close()

	c, err := NewClient(testServer.URL, &AuthConfiguration{PublicKey: "E5I9QKJF1O2B5PXE68LG", PrivateKey: "secret"})
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}

	request := ApplySecurityGroupRequest{
		SecurityGroupID: "sg-D3T3CONW",
		InstanceIDs:     []string{"i-BX08FEXR", "i-C4U0F77C"},
	}
	var response ApplySecurityGroupResponse

	err = c.SendRequest(request, &response)
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}

	expectedResponse := ApplySecurityGroupResponse{
		ResponseCommon: ResponseCommon{
			Action:  "ApplySecurityGroupResponse",
			RetCode: 0,
			Code:    0,
		},
		JobID: "job-V6XF47A0",
	}
	if !reflect.DeepEqual(expectedResponse, response) {
		t.Errorf("Error: expected \n%v, got \n%v", expectedResponse, response)
	}
}

// TestModifySecurityGroupAttributes tests that we send correct request to modify security group attributes.
func TestModifySecurityGroupAttributes(t *testing.T) {
	expectedJson := RemoveWhitespaces(`
{
  "security_group": "sg-EFBL5JC2",
  "token": "E5I9QKJF1O2B5PXE68LG",
  "description": "testidc",
  "security_group_name": "51idc",
  "action": "ModifySecurityGroupAttributes",
  "zone": "ac1"
}
`)

	fakeResponse := RemoveWhitespaces(`
{
  "ret_code": 0,
  "security_group_id": "sg-EFBL5JC2",
  "action": "ModifySecurityGroupAttributesResponse",
  "code": 0,
  "job_id": "job-Z4VNRVCT"
}
`)

	testServer := httptest.NewServer(&FakeHandler{t: t, ExpectedJson: expectedJson, FakeResponse: fakeResponse})
	defer testServer.Close()

	c, err := NewClient(testServer.URL, &AuthConfiguration{PublicKey: "E5I9QKJF1O2B5PXE68LG", PrivateKey: "secret"})
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}

	request := ModifySecurityGroupAttributesRequest{
		SecurityGroupID:   "sg-EFBL5JC2",
		SecurityGroupName: "51idc",
		Description:       "testidc",
	}
	var response ModifySecurityGroupAttributesResponse

	err = c.SendRequest(request, &response)
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}

	expectedResponse := ModifySecurityGroupAttributesResponse{
		ResponseCommon: ResponseCommon{
			Action:  "ModifySecurityGroupAttributesResponse",
			RetCode: 0,
			Code:    0,
		},
		SecurityGroupID: "sg-EFBL5JC2",
		JobID:           "job-Z4VNRVCT",
	}
	if !reflect.DeepEqual(expectedResponse, response) {
		t.Errorf("Error: expected \n%v, got \n%v", expectedResponse, response)
	}
}

// TestDescribeSecurityGroupRules tests that we send correct request to describe security group rules.
func TestDescribeSecurityGroupRules(t *testing.T) {
	expectedJson := RemoveWhitespaces(`
{
  "security_group": "sg-D3T3CONW",
  "token": "E5I9QKJF1O2B5PXE68LG",
  "action": "DescribeSecurityGroupRules",
  "zone": "ac1"
}
`)

	fakeResponse := RemoveWhitespaces(`
{
  "ret_code": 0,
  "action": "DescribeSecurityGroupRulesResponse",
  "item_set": [
    {
      "action": "accept",
      "direction": 0,
      "disabled": 0,
      "security_group_rule_id": "sgr-QKI3K8DA",
      "security_group_rule_name": "ww",
      "priority": 1,
      "protocol": "tcp",
      "val1": "80",
      "val2": "90",
      "val3": "0.0.0.0",
      "security_group_id": "sg-D3T3CONW"
    }
  ],
  "code": 0
}
`)

	testServer := httptest.NewServer(&FakeHandler{t: t, ExpectedJson: expectedJson, FakeResponse: fakeResponse})
	defer testServer.Close()

	c, err := NewClient(testServer.URL, &AuthConfiguration{PublicKey: "E5I9QKJF1O2B5PXE68LG", PrivateKey: "secret"})
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}

	request := DescribeSecurityGroupRulesRequest{
		SecurityGroupID: "sg-D3T3CONW",
	}
	var response DescribeSecurityGroupRulesResponse

	err = c.SendRequest(request, &response)
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}

	expectedResponse := DescribeSecurityGroupRulesResponse{
		ResponseCommon: ResponseCommon{
			Action:  "DescribeSecurityGroupRulesResponse",
			RetCode: 0,
			Code:    0,
		},
		ItemSet: []DescribeSecurityGroupRule{
			{
				SecurityGroupRuleID:   "sgr-QKI3K8DA",
				SecurityGroupRuleName: "ww",
				Priority:              1,
				Disabled:              0,
				Action:                SecurityGroupRuleActionAccept,
				Direction:             SecurityGroupRuleDirectionDown,
				Protocol:              SecurityGroupRuleProtocolTCP,
				Value1:                "80",
				Value2:                "90",
				Value3:                "0.0.0.0",
			},
		},
	}
	if !reflect.DeepEqual(expectedResponse, response) {
		t.Errorf("Error: expected \n%+v, got \n%+v", expectedResponse, response)
	}
}

// TestAddSecurityGroupRules tests that we send correct request to add security group rules.
func TestAddSecurityGroupRules(t *testing.T) {
	expectedJson := RemoveWhitespaces(`
{
  "security_group": "sg-EFBL5JC2",
  "token": "E5I9QKJF1O2B5PXE68LG",
  "action": "AddSecurityGroupRules",
  "zone": "ac1",
  "rules": [
    {
      "rule_action": "accept",
      "protocol": "tcp",
      "security_group_rule_name": "cloud",
      "priority": 6,
      "direction": 0
    }
  ]
}
`)

	fakeResponse := RemoveWhitespaces(`
{
  "ret_code": 0,
  "action": "AddSecurityGroupRulesResponse",
  "security_group_rules": [
    "sgr-OHA6847L"
  ],
  "code": 0,
  "job_id": "job-XVXOO7LE"
}
`)

	testServer := httptest.NewServer(&FakeHandler{t: t, ExpectedJson: expectedJson, FakeResponse: fakeResponse})
	defer testServer.Close()

	c, err := NewClient(testServer.URL, &AuthConfiguration{PublicKey: "E5I9QKJF1O2B5PXE68LG", PrivateKey: "secret"})
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}

	request := AddSecurityGroupRulesRequest{
		SecurityGroupID: "sg-EFBL5JC2",
		SecurityGroupRules: []AddSecurityGroupRule{
			{
				SecurityGroupRuleName: "cloud",
				Priority:              6,
				Action:                SecurityGroupRuleActionAccept,
				Direction:             SecurityGroupRuleDirectionDown,
				Protocol:              SecurityGroupRuleProtocolTCP,
			},
		},
	}
	var response AddSecurityGroupRulesResponse

	err = c.SendRequest(request, &response)
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}

	expectedResponse := AddSecurityGroupRulesResponse{
		ResponseCommon: ResponseCommon{
			Action:  "AddSecurityGroupRulesResponse",
			RetCode: 0,
			Code:    0,
		},
		SecurityGroupRuleIDs: []string{"sgr-OHA6847L"},
		JobID:                "job-XVXOO7LE",
	}
	if !reflect.DeepEqual(expectedResponse, response) {
		t.Errorf("Error: expected \n%+v, got \n%+v", expectedResponse, response)
	}
}

// TestDeleteSecurityGroupRules tests that we send correct request to delete security group rules.
func TestDeleteSecurityGroupRules(t *testing.T) {
	expectedJson := RemoveWhitespaces(`
{
  "token": "E5I9QKJF1O2B5PXE68LG",
  "action": "DeleteSecurityGroupRules",
  "security_group_rules": [
    "sg-D3T3CONW"
  ],
  "zone": "ac1"
}
`)

	fakeResponse := RemoveWhitespaces(`
{
  "ret_code": 0,
  "action": "DeleteSecurityGroupRulesResponse",
  "code": 0,
  "job_id": "job-QOB01QZB"
}
`)

	testServer := httptest.NewServer(&FakeHandler{t: t, ExpectedJson: expectedJson, FakeResponse: fakeResponse})
	defer testServer.Close()

	c, err := NewClient(testServer.URL, &AuthConfiguration{PublicKey: "E5I9QKJF1O2B5PXE68LG", PrivateKey: "secret"})
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}

	request := DeleteSecurityGroupRulesRequest{
		SecurityGroupRuleIDs: []string{"sg-D3T3CONW"},
	}
	var response DeleteSecurityGroupRulesResponse

	err = c.SendRequest(request, &response)
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}

	expectedResponse := DeleteSecurityGroupRulesResponse{
		ResponseCommon: ResponseCommon{
			Action:  "DeleteSecurityGroupRulesResponse",
			RetCode: 0,
			Code:    0,
		},
		JobID: "job-QOB01QZB",
	}
	if !reflect.DeepEqual(expectedResponse, response) {
		t.Errorf("Error: expected \n%+v, got \n%+v", expectedResponse, response)
	}
}

// TestModifySecurityGroupRuleAttributes tests that we send correct request to modify security group rule attributes.
func TestModifySecurityGroupRuleAttributes(t *testing.T) {
	expectedJson := RemoveWhitespaces(`
{
  "rule_action": "accept",
  "security_group": "sg-EFBL5JC2",
  "security_group_rule": "sgr-U3ADXLYV",
  "protocol": "tcp",
  "security_group_rule_name": "cloud",
  "token": "E5I9QKJF1O2B5PXE68LG",
  "priority": 7,
  "direction": 0,
  "action": "ModifySecurityGroupRuleAttributes",
  "zone": "ac1"
}
`)

	fakeResponse := RemoveWhitespaces(`
{
  "ret_code": 0,
  "action": "ModifySecurityGroupRuleAttributesResponse",
  "security_group_rule_id": "sgr-U3ADXLYV",
  "code": 0,
  "job_id": "job-GMZSHI8B"
}
`)

	testServer := httptest.NewServer(&FakeHandler{t: t, ExpectedJson: expectedJson, FakeResponse: fakeResponse})
	defer testServer.Close()

	c, err := NewClient(testServer.URL, &AuthConfiguration{PublicKey: "E5I9QKJF1O2B5PXE68LG", PrivateKey: "secret"})
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}

	request := ModifySecurityGroupRuleAttributesRequest{
		SecurityGroupID:       "sg-EFBL5JC2",
		SecurityGroupRuleID:   "sgr-U3ADXLYV",
		SecurityGroupRuleName: "cloud",
		Priority:              7,
		Action:                SecurityGroupRuleActionAccept,
		Direction:             SecurityGroupRuleDirectionDown,
		Protocol:              SecurityGroupRuleProtocolTCP,
	}
	var response ModifySecurityGroupRuleAttributesResponse

	err = c.SendRequest(request, &response)
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}

	expectedResponse := ModifySecurityGroupRuleAttributesResponse{
		ResponseCommon: ResponseCommon{
			Action:  "ModifySecurityGroupRuleAttributesResponse",
			RetCode: 0,
			Code:    0,
		},
		SecurityGroupRuleID: "sgr-U3ADXLYV",
		JobID:               "job-GMZSHI8B",
	}
	if !reflect.DeepEqual(expectedResponse, response) {
		t.Errorf("Error: expected \n%v, got \n%v", expectedResponse, response)
	}
}
