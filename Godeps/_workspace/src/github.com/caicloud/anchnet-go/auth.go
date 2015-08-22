// Copyright 2015 anchnet-go authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package anchnet

import (
	"encoding/json"
	"io"
	"os"
	"path"
)

type AuthConfiguration struct {
	PublicKey  string `json:"publickey"`
	PrivateKey string `json:"privatekey"`
	ProjectId  string `json:"projectid"`
}

// LoadConfig loads API keys from given path.
func LoadConfig(path string) (*AuthConfiguration, error) {
	r, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	var auth AuthConfiguration
	if err := json.NewDecoder(r).Decode(&auth); err != nil {
		return nil, err
	}
	return &auth, nil
}

// LoadConfigReader loads API keys from given reader.
func LoadConfigReader(config io.Reader) (*AuthConfiguration, error) {
	var auth AuthConfiguration
	if err := json.NewDecoder(config).Decode(&auth); err != nil {
		return nil, err
	}
	return &auth, nil
}

// DefaultConfigPath get default configuration.
func DefaultConfigPath() string {
	return path.Join(os.Getenv("HOME"), ConfigDir, ConfigFile)
}
