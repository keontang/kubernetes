/*
Copyright 2015 The Kubernetes Authors All rights reserved.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package app

import (
	"os"

	"k8s.io/kubernetes/pkg/kubectl/cmd"
	cmdutil "k8s.io/kubernetes/pkg/kubectl/cmd/util"
)

/*
https://github.com/spf13/cobra
Cobra is both a library for creating powerful modern CLI applications
as well as a program to generate applications and command files.
Many of the most widely used Go projects are built using Cobra including:
  Kubernetes
  Etcd
  OpenShift
  ...

Cobra is a library providing a simple interface to create powerful modern CLI interfaces similar to git & go tools.

Cobra is also an application that will generate your application scaffolding to rapidly develop a Cobra-based application.

The pattern to follow is APPNAME VERB NOUN --ADJECTIVE. or APPNAME COMMAND ARG --FLAG
Commands represent actions, Args are things and Flags are modifiers for those actions.

kubectl is an application.
*/
func Run() error {
	cmd := cmd.NewKubectlCommand(cmdutil.NewFactory(nil), os.Stdin, os.Stdout, os.Stderr)
	return cmd.Execute()
}
