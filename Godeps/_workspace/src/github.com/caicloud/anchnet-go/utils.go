// Copyright 2015 anchnet-go authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package anchnet

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"io/ioutil"
	"net/http"
	"reflect"
	"regexp"
	"testing"
)

// RemoveWhitespaces removes all white spaces from a string, return a new string.
func RemoveWhitespaces(str string) string {
	re := regexp.MustCompile("[\n\r\\s]+")
	return re.ReplaceAllString(str, "")
}

// GenSignature generates hex encoded signature for 'data' using 'key'.
// Steps are described at: http://cloud.51idc.com/help/api/signature.html
func GenSignature(data []byte, key []byte) string {
	mac := hmac.New(sha256.New, key)
	mac.Write(data)
	return hex.EncodeToString(mac.Sum(nil))
}

// FakeHandler is a fake http handler, used in unittest.
type FakeHandler struct {
	ExpectedJson string
	FakeResponse string

	t *testing.T
}

func (f *FakeHandler) ServeHTTP(response http.ResponseWriter, request *http.Request) {
	body, _ := ioutil.ReadAll(request.Body)
	var expect, actual map[string]interface{}
	err := json.Unmarshal([]byte(f.ExpectedJson), &expect)
	if err != nil {
		f.t.Errorf("Error: unexpected error unmarshaling expected json: %v", err)
	}
	err = json.Unmarshal(body, &actual)
	if err != nil {
		f.t.Errorf("Error: unexpected error unmarshaling request body: %v", err)
	}
	if !reflect.DeepEqual(expect, actual) {
		f.t.Errorf("Error: expected \n%v, got \n%v", expect, actual)
	}
	response.Write([]byte(f.FakeResponse))
}
