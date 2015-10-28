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

func execDescribeVolumes(cmd *cobra.Command, args []string, client *anchnet.Client, out io.Writer) {
	if len(args) == 0 {
		fmt.Fprintln(os.Stderr, "Volume IDs required")
		os.Exit(1)
	}

	request := anchnet.DescribeVolumesRequest{
		VolumeIDs: strings.Split(args[0], ","),
	}
	var response anchnet.DescribeVolumesResponse
	sendResult(&response, out, "DescribeVolumes", response.Code, client.SendRequest(request, &response))
}
