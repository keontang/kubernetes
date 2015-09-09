// Copyright 2015 anchnet-go authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package main

import (
	"fmt"
	"io"
	"os"
	"strconv"
	"strings"

	anchnet "github.com/caicloud/anchnet-go"
	"github.com/spf13/cobra"
)

func execCreateSecurityGroup(cmd *cobra.Command, args []string, client *anchnet.Client, out io.Writer) {
	if len(args) != 1 {
		fmt.Fprintln(os.Stderr, "Security group name required")
		os.Exit(1)
	}

	// Assume number matches.
	rulename := strings.Split(getFlagString(cmd, "rulename"), ",")
	priority := strings.Split(getFlagString(cmd, "priority"), ",")
	direction := strings.Split(getFlagString(cmd, "direction"), ",")
	action := strings.Split(getFlagString(cmd, "action"), ",")
	protocol := strings.Split(getFlagString(cmd, "protocol"), ",")
	value1 := strings.Split(getFlagString(cmd, "value1"), ",")
	value2 := strings.Split(getFlagString(cmd, "value2"), ",")

	var rules []anchnet.CreateSecurityGroupRule
	for i := range rulename {
		d, _ := strconv.Atoi(direction[i])
		p, _ := strconv.Atoi(priority[i])
		rule := anchnet.CreateSecurityGroupRule{
			SecurityGroupRuleName: rulename[i],
			Action:                anchnet.SecurityGroupRuleAction(action[i]),
			Direction:             anchnet.SecurityGroupRuleDirection(d),
			Protocol:              anchnet.SecurityGroupRuleProtocol(protocol[i]),
			Priority:              p,
			Value1:                value1[i],
			Value2:                value2[i],
		}
		rules = append(rules, rule)
	}

	request := anchnet.CreateSecurityGroupRequest{
		SecurityGroupName:  args[0],
		SecurityGroupRules: rules,
	}
	var response anchnet.CreateSecurityGroupResponse
	sendResult(&response, out, "CreateSecurityGroup", response.Code, client.SendRequest(request, &response))
}

func execDescribeSecurityGroup(cmd *cobra.Command, args []string, client *anchnet.Client, out io.Writer) {
	if len(args) != 1 {
		fmt.Fprintln(os.Stderr, "Security group IDs required")
		os.Exit(1)
	}

	request := anchnet.DescribeSecurityGroupsRequest{
		SecurityGroupIDs: []string{args[0]},
		Verbose:          1,
	}
	var response anchnet.DescribeSecurityGroupsResponse
	sendResult(&response, out, "DescribeSecurityGroup", response.Code, client.SendRequest(request, &response))
}

func execSearchSecurityGroup(cmd *cobra.Command, args []string, client *anchnet.Client, out io.Writer) {
	if len(args) != 1 {
		fmt.Fprintln(os.Stderr, "Security group name required")
		os.Exit(1)
	}

	request := anchnet.DescribeSecurityGroupsRequest{
		SearchWord: args[0],
		Verbose:    1,
	}
	var response anchnet.DescribeSecurityGroupsResponse
	sendResult(&response, out, "SearchSecurityGroup", response.Code, client.SendRequest(request, &response))
}

func execAddSecurityGroupRule(cmd *cobra.Command, args []string, client *anchnet.Client, out io.Writer) {
	if len(args) != 2 {
		fmt.Fprintln(os.Stderr, "Rule name and security group ID required")
		os.Exit(1)
	}

	priority := getFlagInt(cmd, "priority")
	direction := getFlagInt(cmd, "direction")
	action := getFlagString(cmd, "action")
	protocol := getFlagString(cmd, "protocol")
	value1 := getFlagString(cmd, "value1")
	value2 := getFlagString(cmd, "value2")
	value3 := getFlagString(cmd, "value3")

	request := anchnet.AddSecurityGroupRulesRequest{
		SecurityGroupID: args[1],
		SecurityGroupRules: []anchnet.AddSecurityGroupRule{
			{
				SecurityGroupRuleName: args[0],
				Action:                anchnet.SecurityGroupRuleAction(action),
				Direction:             anchnet.SecurityGroupRuleDirection(direction),
				Protocol:              anchnet.SecurityGroupRuleProtocol(protocol),
				Priority:              priority,
				Value1:                value1,
				Value2:                value2,
				Value3:                value3,
			},
		},
	}
	var response anchnet.AddSecurityGroupRulesResponse
	sendResult(&response, out, "AddSecurityGroup", response.Code, client.SendRequest(request, &response))
}

func execApplySecurityGroup(cmd *cobra.Command, args []string, client *anchnet.Client, out io.Writer) {
	if len(args) != 2 {
		fmt.Fprintln(os.Stderr, "Security group id and instance ids required")
		os.Exit(1)
	}

	request := anchnet.ApplySecurityGroupRequest{
		SecurityGroupID: args[0],
		InstanceIDs:     strings.Split(args[1], ","),
	}
	var response anchnet.ApplySecurityGroupResponse
	sendResult(&response, out, "ApplySecurityGroup", response.Code, client.SendRequest(request, &response))
}

func execDeleteSecurityGroups(cmd *cobra.Command, args []string, client *anchnet.Client, out io.Writer) {
	if len(args) != 1 {
		fmt.Fprintln(os.Stderr, "Security group IDs required")
		os.Exit(1)
	}

	request := anchnet.DeleteSecurityGroupsRequest{
		SecurityGroupIDs: strings.Split(args[0], ","),
	}
	var response anchnet.DeleteSecurityGroupsResponse
	sendResult(&response, out, "DeleteSecurityGroups", response.Code, client.SendRequest(request, &response))
}
