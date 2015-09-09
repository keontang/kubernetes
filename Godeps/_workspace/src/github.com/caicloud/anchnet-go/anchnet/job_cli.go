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
	sendResult(&response, out, "DescribeJob", response.Code, client.SendRequest(request, &response))
}

func execWaitJob(cmd *cobra.Command, args []string, client *anchnet.Client, out io.Writer) {
	if len(args) == 0 {
		fmt.Fprintln(os.Stderr, "Job id required")
		os.Exit(1)
	}

	count := getFlagInt(cmd, "count")
	status := getFlagString(cmd, "status")
	interval := getFlagInt(cmd, "interval")
	exitOnFail := getFlagBool(cmd, "exit_on_fail")

	for i := 0; i < count; i++ {
		request := anchnet.DescribeJobsRequest{
			JobIDs: []string{args[0]},
		}
		var response anchnet.DescribeJobsResponse
		err := client.SendRequest(request, &response)
		if err == nil && len(response.ItemSet) == 1 {
			// Return if there is no error and status matches.
			if string(response.ItemSet[0].Status) == status {
				return
			}
			// Return if there is no error, and status is failed + user wants early return.
			if response.ItemSet[0].Status == anchnet.JobStatusFailed && exitOnFail {
				fmt.Fprintf(os.Stderr, "Job %v failed", args[0])
				os.Exit(1)
			}
		}
		time.Sleep(time.Duration(interval) * time.Second)
	}
	fmt.Fprintf(os.Stderr, "Time out waiting for job %v", args[0])
	os.Exit(1)
}
