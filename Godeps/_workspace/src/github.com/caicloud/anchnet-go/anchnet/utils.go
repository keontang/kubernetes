// Copyright 2015 anchnet-go authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package main

import (
	"strconv"

	"github.com/caicloud/anchnet-go/vendor/_nuts/github.com/spf13/cobra"
	"github.com/caicloud/anchnet-go/vendor/_nuts/github.com/spf13/pflag"
	"github.com/golang/glog"
)

func getFlag(cmd *cobra.Command, flag string) *pflag.Flag {
	f := cmd.Flags().Lookup(flag)
	if f == nil {
		glog.Fatalf("flag accessed but not defined for command %s: %s", cmd.Name(), flag)
	}
	return f
}

func GetFlagString(cmd *cobra.Command, flag string) string {
	f := getFlag(cmd, flag)
	return f.Value.String()
}

func GetFlagBool(cmd *cobra.Command, flag string) bool {
	f := getFlag(cmd, flag)
	result, err := strconv.ParseBool(f.Value.String())
	if err != nil {
		glog.Fatalf("Invalid value for a boolean flag: %s", f.Value.String())
	}
	return result
}

func GetFlagInt(cmd *cobra.Command, flag string) int {
	f := getFlag(cmd, flag)
	// Assumes the flag has a default value.
	v, err := strconv.Atoi(f.Value.String())
	// This is likely not a sufficiently friendly error message, but cobra
	// should prevent non-integer values from reaching here.
	if err != nil {
		glog.Fatalf("unable to convert flag value to int: %v", err)
	}
	return v
}
