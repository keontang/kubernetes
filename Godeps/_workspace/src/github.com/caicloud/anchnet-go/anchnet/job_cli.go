// Copyright 2015 anchnet-go authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package main

import (
	"fmt"
	"io"
	"os"

	"github.com/caicloud/anchnet-go"
	"github.com/spf13/cobra"
)

func execDescribeJob(cmd *cobra.Command, args []string, client *anchnet.Client, out io.Writer) {
	if len(args) == 0 {
		fmt.Fprintln(os.Stderr, "Job id required")
		os.Exit(1)
	}

	request := anchnet.DescribeJobsRequest{
		JobIDs: []string{args[0]},
	}
	var response anchnet.DescribeJobsResponse

	err := client.SendRequest(request, &response)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error running command DescribeJob: %v\n", err)
		os.Exit(1)
	}

	sendResult(response, out)
}
