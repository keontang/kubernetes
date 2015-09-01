// Copyright 2015 anchnet-go authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package main

import (
	"fmt"
	"io"
	"os"

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

	err := client.SendRequest(request, &response)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error running command CreateUserProject: %v\n", err)
		os.Exit(1)
	}

	sendResult(response, out)
}
