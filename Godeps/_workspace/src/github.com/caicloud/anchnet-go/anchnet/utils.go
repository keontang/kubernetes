// Copyright 2015 anchnet-go authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package main

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"strconv"

	"github.com/caicloud/anchnet-go"
	"github.com/spf13/cobra"
	"github.com/spf13/pflag"
)

func getFlagString(cmd *cobra.Command, flag string) string {
	f := getFlag(cmd, flag)
	return f.Value.String()
}

func getFlagBool(cmd *cobra.Command, flag string) bool {
	f := getFlag(cmd, flag)
	result, err := strconv.ParseBool(f.Value.String())
	if err != nil {
		fmt.Fprintln(os.Stderr, "Invalid value for a boolean flag: %s", f.Value.String())
		os.Exit(1)
	}
	return result
}

func getFlagInt(cmd *cobra.Command, flag string) int {
	f := getFlag(cmd, flag)
	// Assumes the flag has a default value.
	v, err := strconv.Atoi(f.Value.String())
	// This is likely not a sufficiently friendly error message, but cobra
	// should prevent non-integer values from reaching here.
	if err != nil {
		fmt.Fprintln(os.Stderr, "unable to convert flag value to int: %v", err)
		os.Exit(1)
	}
	return v
}

func getFlag(cmd *cobra.Command, flag string) *pflag.Flag {
	f := cmd.Flags().Lookup(flag)
	if f == nil {
		fmt.Fprintln(os.Stderr, "flag accessed but not defined for command %s: %s", cmd.Name(), flag)
		os.Exit(1)
	}
	return f
}

// getAnchnetClient returns the path to configuration file.
func getAnchnetClient(cmd *cobra.Command) *anchnet.Client {
	f := cmd.InheritedFlags().Lookup("config-path")
	p := cmd.InheritedFlags().Lookup("project")

	if f == nil {
		fmt.Fprintln(os.Stderr, "flag accessed but not defined for command %s: config-path", cmd.Name())
		os.Exit(1)
	}
	path := f.Value.String()
	if path == "" {
		path = anchnet.DefaultConfigPath()
	}

	if p == nil {
		fmt.Fprintln(os.Stderr, "flag accessed but not defined for command %s: project", cmd.Name())
		os.Exit(1)
	}

	auth, err := anchnet.LoadConfig(path)
	if err != nil {
		fmt.Fprintln(os.Stderr, "error loading auth config: %v", err)
		os.Exit(1)
	}

	// we only set ProjectId if --project is set because
	// projectid can also be set in config file itself already
	project := p.Value.String()
	if project != "" {
		auth.ProjectId = project
	}

	client, err := anchnet.NewClient(anchnet.DefaultEndpoint, auth)
	if err != nil {
		fmt.Fprintln(os.Stderr, "error creating client: %v", err)
		os.Exit(1)
	}

	return client
}

// sendResult sends response to out. cmdName is the command name that we just sent to
// anchnet; code is response.Code and err is from clinet.SendRequest(). The last three
// parameters are needed since we use interface{} type for response.
func sendResult(response interface{}, out io.Writer, cmdName string, code int, err error) {
	// If anchnet error code == 0 but err != nil, we encountered unexpected exceptions.
	if err != nil && code == 0 {
		fmt.Fprintf(os.Stderr, "Unexpected error running command %v: %v\n", cmdName, err)
		os.Exit(1)
	}

	output, err := json.Marshal(response)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Unexpected error marshaling output for command %v: %v\n", cmdName, err)
		os.Exit(1)
	}

	// If we did receive a response, send it to client, regardless of error code from anchnet.
	// However, we exit with non-zero if code != 0.
	fmt.Fprintf(out, "%v", string(output))
	if code != 0 {
		os.Exit(1)
	}
}
