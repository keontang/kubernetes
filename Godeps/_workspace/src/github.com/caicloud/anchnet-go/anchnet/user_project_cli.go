// Copyright 2015 anchnet-go authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package main

import (
	"fmt"
	"io"
	"os"
	"strconv"

	anchnet "github.com/caicloud/anchnet-go"
	"github.com/spf13/cobra"
)

func execCreateUserProject(cmd *cobra.Command, args []string, client *anchnet.Client, out io.Writer) {
	if len(args) == 0 {
		fmt.Fprintln(os.Stderr, "Login id required")
		os.Exit(1)
	}

	sex := getFlagString(cmd, "sex")
	mobile := getFlagString(cmd, "mobile")
	passwd := getFlagString(cmd, "passwd")

	// use {userid}@caicloud.io as loginid which is
	// supposed to be unique
	loginId := args[0] + "@caicloud.io"

	request := anchnet.CreateUserProjectRequest{
		LoginId:     loginId,
		Sex:         sex,
		ProjectName: args[0],
		Email:       loginId,
		ContactName: args[0],
		Mobile:      mobile,
		LoginPasswd: passwd,
	}
	var response anchnet.CreateUserProjectResponse
	sendResult(&response, out, "CreateUserProject", response.Code, client.SendRequest(request, &response))
}

func execDescribeProjects(cmd *cobra.Command, args []string, client *anchnet.Client, out io.Writer) {
	if len(args) == 0 {
		fmt.Fprintln(os.Stderr, "projectid required")
		os.Exit(1)
	}

	request := anchnet.DescribeProjectsRequest{
		Projects: args[0],
	}

	var response anchnet.DescribeProjectsResponse
	sendResult(&response, out, "DescribeProjects", response.Code, client.SendRequest(request, &response))
}

func execTransfer(cmd *cobra.Command, args []string, client *anchnet.Client, out io.Writer) {
	if len(args) != 2 {
		fmt.Fprintln(os.Stderr, "userid and value required")
		os.Exit(1)
	}

	why := getFlagString(cmd, "why")

	// userId is a integer value.
	userId, err := strconv.Atoi(args[0])
	if err != nil {
		fmt.Fprintln(os.Stderr, "unable to convert userId to int: %v", err)
		os.Exit(1)
	}

	request := anchnet.TransferRequest{
		UserId: userId,
		Value:  args[1],
		Why:    why,
	}

	var response anchnet.TransferResponse
	sendResult(&response, out, "Transfer", response.Code, client.SendRequest(request, &response))
}

func execSearchUserProject(cmd *cobra.Command, args []string, client *anchnet.Client, out io.Writer) {
	if len(args) == 0 {
		fmt.Fprintln(os.Stderr, "loginId required")
		os.Exit(1)
	}

	loginId := args[0] + "@caicloud.io"

	request := anchnet.DescribeProjectsRequest{
		SearchWord: loginId,
	}

	var response anchnet.DescribeProjectsResponse
	sendResult(&response, out, "SearchUserProject", response.Code, client.SendRequest(request, &response))
}
