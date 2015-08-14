// Copyright 2015 anchnet-go authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package main

import (
	"fmt"
	"io"
	"os"
	"time"

	anchnet "github.com/caicloud/anchnet-go"
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

func execWaitJob(cmd *cobra.Command, args []string, client *anchnet.Client, out io.Writer) {
	if len(args) == 0 {
		fmt.Fprintln(os.Stderr, "Job id required")
		os.Exit(1)
	}

	count := getFlagInt(cmd, "count")
	interval := getFlagInt(cmd, "interval")
	status := getFlagString(cmd, "status")

	for i := 0; i < count; i++ {
		request := anchnet.DescribeJobsRequest{
			JobIDs: []string{args[0]},
		}
		var response anchnet.DescribeJobsResponse
		err := client.SendRequest(request, &response)
		if err == nil && len(response.ItemSet) == 1 && string(response.ItemSet[0].Status) == status {
			return
		}
		time.Sleep(time.Duration(interval) * time.Second)
	}
	fmt.Fprintf(os.Stderr, "Time out waiting for job %v", args[0])
	os.Exit(1)
}
