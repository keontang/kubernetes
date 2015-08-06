// Copyright 2015 anchnet-go authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package main

import (
	"fmt"
	"io"
	"os"
	"strings"

	anchnet "github.com/caicloud/anchnet-go"
	"github.com/spf13/cobra"
)

func execCreateSecurityGroup(cmd *cobra.Command, args []string, client *anchnet.Client, out io.Writer) {
	if len(args) != 2 {
		fmt.Fprintln(os.Stderr, "Security group name and rule name required")
		os.Exit(1)
	}

	priority := getFlagInt(cmd, "priority")
	direction := getFlagInt(cmd, "direction")
	action := getFlagString(cmd, "action")
	protocol := getFlagString(cmd, "protocol")
	value1 := getFlagString(cmd, "value1")
	value2 := getFlagString(cmd, "value2")
	value3 := getFlagString(cmd, "value3")

	request := anchnet.CreateSecurityGroupRequest{
		SecurityGroupName: args[0],
		SecurityGroupRules: []anchnet.CreateSecurityGroupRule{
			{
				SecurityGroupRuleName: args[1],
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
	var response anchnet.CreateSecurityGroupResponse

	err := client.SendRequest(request, &response)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error running command CreateSecurityGroup: %v\n", err)
		os.Exit(1)
	}

	sendResult(response, out)
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

	err := client.SendRequest(request, &response)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error running command AddSecurityGroup: %v\n", err)
		os.Exit(1)
	}

	sendResult(response, out)
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

	err := client.SendRequest(request, &response)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error running command ApplySecurityGroup: %v\n", err)
		os.Exit(1)
	}

	sendResult(response, out)
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

	err := client.SendRequest(request, &response)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error running command DeleteSecurityGroups: %v\n", err)
		os.Exit(1)
	}

	sendResult(response, out)
}
