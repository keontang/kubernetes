// Copyright 2015 anchnet-go authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package anchnet

// Implements all anchnet security group (firewall) related APIs.

//
// DescribeSecurityGroups retrieves information of a list of security groups.
//
type DescribeSecurityGroupsRequest struct {
	RequestCommon    `json:",inline"`
	SecurityGroupIDs []string `json:"security_groups,omitempty"`
	SearchWord       string   `json:"search_word,omitempty"`
	Verbose          int      `json:"verbose,omitempty"`
	Offset           int      `json:"offset,omitempty"`
	Limit            int      `json:"limit,omitempty"`
}

type DescribeSecurityGroupsResponse struct {
	ResponseCommon `json:",inline"`
	TotalCount     int                          `json:"total_count,omitempty"`
	ItemSet        []DescribeSecurityGroupsItem `json:"item_set,omitempty"`
}

type DescribeSecurityGroupsItem struct {
	SecurityGroupID    string                      `json:"security_group_id,omitempty"`
	SecurityGroupName  string                      `json:"security_group_name,omitempty"`
	Description        string                      `json:"description,omitempty"`
	CreateTime         string                      `json:"create_time,omitempty"`
	Disabled           int                         `json:"disabled,omitempty"`
	IsDefault          int                         `json:"is_default,omitempty"`
	IsApplied          int                         `json:"is_applied,omitempty"`
	SecurityGroupRules []DescribeSecurityGroupRule `json:"rule,omitempty"`
}

type DescribeSecurityGroupRule struct {
	SecurityGroupRuleID   string                     `json:"security_group_rule_id,omitempty"`
	SecurityGroupRuleName string                     `json:"security_group_rule_name,omitempty"`
	Action                SecurityGroupRuleAction    `json:"action,omitempty"`
	Direction             SecurityGroupRuleDirection `json:"direction"` // Do not omit empty for direction=down
	Protocol              SecurityGroupRuleProtocol  `json:"protocol,omitempty"`
	Disabled              int                        `json:"disabled,omitempty"`
	Priority              int                        `json:"priority,omitempty"`
	Value1                string                     `json:"val1,omitempty"`
	Value2                string                     `json:"val2,omitempty"`
	Value3                string                     `json:"val3,omitempty"`
	Resources             []SecurityGroupResource    `json:"resource,omitempty"`
}

type SecurityGroupResource struct {
	ResourceID   string `json:"resource_id,omitempty"`
	ResourceName string `json:"resource_name,omitempty"`
	ResourceType string `json:"resource_type,omitempty"`
}

type SecurityGroupRuleDirection int

const (
	SecurityGroupRuleDirectionDown SecurityGroupRuleDirection = 0
	SecurityGroupRuleDirectionUp   SecurityGroupRuleDirection = 1
)

type SecurityGroupRuleAction string

const (
	SecurityGroupRuleActionAccept SecurityGroupRuleAction = "accept"
	SecurityGroupRuleActionDrop   SecurityGroupRuleAction = "drop"
)

type SecurityGroupRuleProtocol string

const (
	SecurityGroupRuleProtocolTCP  SecurityGroupRuleProtocol = "tcp"
	SecurityGroupRuleProtocolUDP  SecurityGroupRuleProtocol = "udp"
	SecurityGroupRuleProtocolICMP SecurityGroupRuleProtocol = "icmp"
)

//
// CreateSecurityGroup creates a security group.
//
type CreateSecurityGroupRequest struct {
	RequestCommon      `json:",inline"`
	SecurityGroupName  string                    `json:"security_group_name,omitempty"`
	SecurityGroupRules []CreateSecurityGroupRule `json:"rule,omitempty"`
}

type CreateSecurityGroupResponse struct {
	ResponseCommon  `json:",inline"`
	JobID           string `json:"job_id,omitempty"`
	SecurityGroupID string `json:"security_group_id,omitempty"`
}

type CreateSecurityGroupRule struct {
	SecurityGroupRuleID   string                     `json:"security_group_rule_id,omitempty"`
	SecurityGroupRuleName string                     `json:"security_group_rule_name,omitempty"`
	Action                SecurityGroupRuleAction    `json:"action,omitempty"`
	Direction             SecurityGroupRuleDirection `json:"direction"`
	Protocol              SecurityGroupRuleProtocol  `json:"protocol,omitempty"`
	Disabled              int                        `json:"disabled,omitempty"`
	Priority              int                        `json:"priority,omitempty"`
	Value1                string                     `json:"val1,omitempty"`
	Value2                string                     `json:"val2,omitempty"`
	Value3                string                     `json:"val3,omitempty"`
	Resources             []SecurityGroupResource    `json:"resource,omitempty"`
}

//
// DeleteSecurityGroups deletes a list of security group.
//
type DeleteSecurityGroupsRequest struct {
	RequestCommon    `json:",inline"`
	SecurityGroupIDs []string `json:"security_groups,omitempty"`
}

type DeleteSecurityGroupsResponse struct {
	ResponseCommon `json:",inline"`
	JobID          string `json:"job_id,omitempty"`
}

// ApplySecurityGroup applies a security group to a list of instances.
type ApplySecurityGroupRequest struct {
	RequestCommon   `json:",inline"`
	SecurityGroupID string   `json:"security_group,omitempty"`
	InstanceIDs     []string `json:"instances,omitempty"`
}

type ApplySecurityGroupResponse struct {
	ResponseCommon `json:",inline"`
	JobID          string `json:"job_id,omitempty"`
}

//
// ModifySecurityGroupAttributes modifies attributes of a security group.
//
type ModifySecurityGroupAttributesRequest struct {
	RequestCommon     `json:",inline"`
	SecurityGroupID   string `json:"security_group,omitempty"`
	SecurityGroupName string `json:"security_group_name,omitempty"`
	Description       string `json:"description,omitempty"`
}

type ModifySecurityGroupAttributesResponse struct {
	ResponseCommon  `json:",inline"`
	JobID           string `json:"job_id,omitempty"`
	SecurityGroupID string `json:"security_group_id,omitempty"`
}

//
// DescribeSecurityGroupRules retrieves information of a list of security group rules.
// If only SecurityGroupID is given, then all rules in the group will be listed.
//
type DescribeSecurityGroupRulesRequest struct {
	RequestCommon        `json:",inline"`
	SecurityGroupID      string                     `json:"security_group,omitempty"`
	SecurityGroupRuleIDs []string                   `json:"security_group_rules,omitempty"`
	Direction            SecurityGroupRuleDirection `json:"direction,omitempty"`
}

type DescribeSecurityGroupRulesResponse struct {
	ResponseCommon `json:",inline"`
	TotalCount     int                         `json:"total_count,omitempty"`
	ItemSet        []DescribeSecurityGroupRule `json:"item_set,omitempty"`
}

//
// AddSecurityGroupRules adds a list of security group rules to a security group.
//
type AddSecurityGroupRulesRequest struct {
	RequestCommon      `json:",inline"`
	SecurityGroupID    string                 `json:"security_group,omitempty"`
	SecurityGroupRules []AddSecurityGroupRule `json:"rules,omitempty"`
}

type AddSecurityGroupRulesResponse struct {
	ResponseCommon       `json:",inline"`
	JobID                string   `json:"job_id,omitempty"`
	SecurityGroupRuleIDs []string `json:"security_group_rules,omitempty"`
}

type AddSecurityGroupRule struct {
	SecurityGroupRuleID   string                     `json:"security_group_rule_id,omitempty"`
	SecurityGroupRuleName string                     `json:"security_group_rule_name,omitempty"`
	Action                SecurityGroupRuleAction    `json:"rule_action,omitempty"`
	Direction             SecurityGroupRuleDirection `json:"direction"`
	Protocol              SecurityGroupRuleProtocol  `json:"protocol,omitempty"`
	Disabled              int                        `json:"disabled,omitempty"`
	Priority              int                        `json:"priority,omitempty"`
	Value1                string                     `json:"val1,omitempty"`
	Value2                string                     `json:"val2,omitempty"`
	Value3                string                     `json:"val3,omitempty"`
	Resources             []SecurityGroupResource    `json:"resource,omitempty"`
}

//
// DeleteSecurityGroupRules deletes a list of security group rules to a security group.
//
type DeleteSecurityGroupRulesRequest struct {
	RequestCommon        `json:",inline"`
	SecurityGroupRuleIDs []string `json:"security_group_rules,omitempty"`
}

type DeleteSecurityGroupRulesResponse struct {
	ResponseCommon `json:",inline"`
	JobID          string `json:"job_id,omitempty"`
}

//
// ModifySecurityGroupRuleAttributes modifies a security group rule.
//
type ModifySecurityGroupRuleAttributesRequest struct {
	RequestCommon         `json:",inline"`
	SecurityGroupID       string                     `json:"security_group,omitempty"`
	SecurityGroupRuleID   string                     `json:"security_group_rule,omitempty"`
	SecurityGroupRuleName string                     `json:"security_group_rule_name,omitempty"`
	Action                SecurityGroupRuleAction    `json:"rule_action,omitempty"`
	Direction             SecurityGroupRuleDirection `json:"direction"`
	Protocol              SecurityGroupRuleProtocol  `json:"protocol,omitempty"`
	Disabled              int                        `json:"disabled,omitempty"`
	Priority              int                        `json:"priority,omitempty"`
	Value1                string                     `json:"val1,omitempty"`
	Value2                string                     `json:"val2,omitempty"`
	Value3                string                     `json:"val3,omitempty"`
	Resources             []SecurityGroupResource    `json:"resource,omitempty"`
}

type ModifySecurityGroupRuleAttributesResponse struct {
	ResponseCommon      `json:",inline"`
	SecurityGroupRuleID string `json:"security_group_rule_id,omitempty"`
	JobID               string `json:"job_id,omitempty"`
}
