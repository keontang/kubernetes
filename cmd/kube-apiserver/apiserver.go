/*
Copyright 2014 The Kubernetes Authors All rights reserved.

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

// apiserver is the main api server and master for the cluster.
// it is responsible for serving the cluster management API.
package main

import (
	"fmt"
	"math/rand"
	"os"
	"runtime"
	"time"

	"k8s.io/kubernetes/cmd/kube-apiserver/app"
	"k8s.io/kubernetes/cmd/kube-apiserver/app/options"
	"k8s.io/kubernetes/pkg/util"
	"k8s.io/kubernetes/pkg/version/verflag"

	"github.com/spf13/pflag"
)

func main() {
	runtime.GOMAXPROCS(runtime.NumCPU())
	rand.Seed(time.Now().UTC().UnixNano())

	s := options.NewAPIServer() // 使用默认参数创建一个 APIServer 对象
	/* gflags 是 google 开源的一套命令行参数处理的开源库. 比 getopt 更方便, 更功能强大,
	 * 使用 c++ 开发, 具备 python 接口, 可以替代 getopt.
	 * Golang 的标准库 (http://golang.org/pkg/flag) 提供了等价于 gflags 的功能.
	 * 而 pflag 是 flag 的升级版本, 完全兼容之前的 flag 标准库.
	 * Golang flag 库处理命令行参数选项的步骤如下:
	 *   1. 通过 flag.String(), Bool(), Int() 等方式来定义应用程序需要使用的 flag
	 *   2. 通过调用 flag.Parse() 来进行对命令行参数的解析, flag.Parse() 实际上是从
	 *      os.Args[] 中获取用户输入的命令行参数选项, 并进行解析的
	 */
	s.AddFlags(pflag.CommandLine) // 为 APIServer 对象添加支持的命令行参数选项

	util.InitFlags() // 标准化用户输入命令行参数选项格式, 然后进行解析
	util.InitLogs()
	defer util.FlushLogs()

	verflag.PrintAndExitIfRequested()

	if err := app.Run(s); err != nil { // 运行 kube-apiserver
		fmt.Fprintf(os.Stderr, "%v\n", err)
		os.Exit(1)
	}
}
