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

package transport

/*
 * 传输层安全协议（Transport Layer Security，缩写：TLS），
 * 及其前身安全套接层（Secure Sockets Layer，缩写：SSL）是一种安全协议，
 * 目的是为互联网通信提供安全及数据完整性保障
 * SSL/TLS 是一个介于 HTTP 协议与 TCP 之间的一个可选层
 *
 * SSL/TLS 协议提供的服务主要有:
 *   1. 认证用户和服务器，确保数据发送到正确的客户机和服务器
 *   2. 加密数据以防止数据中途被窃取
 *   3. 维护数据的完整性，确保数据在传输过程中不被改变
 */

import "net/http"

// Config holds various options for establishing a transport.
type Config struct {
	// UserAgent is an optional field that specifies the caller of this
	// request.
	UserAgent string

	// The base TLS configuration for this transport.
	TLS TLSConfig

	// Username and password for basic authentication
	Username string
	Password string

	// Bearer token for authentication
	BearerToken string

	// Transport may be used for custom HTTP behavior. This attribute may
	// not be specified with the TLS client certificate options. Use
	// WrapTransport for most client level operations.
	/*
	 * RoundTripper is an interface representing the ability to execute a
	 * single HTTP transaction, obtaining the Response for a given Request.
	 *
	 * RoundTrip executes a single HTTP transaction, returning the Response
	 * for the request req. (RoundTrip 代表一个 http 事务，给一个请求返回一个响应)
	 *
	 * golang net/http库发送http请求，最后都是调用 transport的 RoundTrip方法
	 *
	 * 无论是 roundtrip, 还是 transport, 都是http包, 并不是tcp/ip的传输层
	 * 只是他在代码实现的过程中取了这个名字
	 */
	Transport http.RoundTripper

	// WrapTransport will be invoked for custom HTTP behavior after the
	// underlying transport is initialized (either the transport created
	// from TLSClientConfig, Transport, or http.DefaultTransport). The
	// config may layer other RoundTrippers on top of the returned
	// RoundTripper.
	WrapTransport func(rt http.RoundTripper) http.RoundTripper
}

// HasCA returns whether the configuration has a certificate authority or not.
func (c *Config) HasCA() bool {
	return len(c.TLS.CAData) > 0 || len(c.TLS.CAFile) > 0
}

// HasBasicAuth returns whether the configuration has basic authentication or not.
func (c *Config) HasBasicAuth() bool {
	return len(c.Username) != 0
}

// HasTokenAuth returns whether the configuration has token authentication or not.
func (c *Config) HasTokenAuth() bool {
	return len(c.BearerToken) != 0
}

// HasCertAuth returns whether the configuration has certificate authentication or not.
func (c *Config) HasCertAuth() bool {
	return len(c.TLS.CertData) != 0 || len(c.TLS.CertFile) != 0
}

// TLSConfig holds the information needed to set up a TLS transport.
type TLSConfig struct {
	CAFile   string // Path of the PEM-encoded server trusted root certificates.
	CertFile string // Path of the PEM-encoded client certificate.
	KeyFile  string // Path of the PEM-encoded client key.

	Insecure bool // Server should be accessed without verifying the certificate. For testing only.

	CAData   []byte // Bytes of the PEM-encoded server trusted root certificates. Supercedes CAFile.
	CertData []byte // Bytes of the PEM-encoded client certificate. Supercedes CertFile.
	KeyData  []byte // Bytes of the PEM-encoded client key. Supercedes KeyFile.
}
