// Copyright 2015 anchnet-go authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package anchnet

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
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

// DeepCopy performs a deep copy of a given object, returns an interface
// which is a pointer to the copied data.
func Deepcopy(in interface{}) (interface{}, error) {
	inValue := reflect.ValueOf(in)
	outValue, err := deepCopy(inValue)
	if err != nil {
		return nil, err
	}
	if outValue.Kind() == reflect.Ptr {
		return outValue.Interface(), nil
	} else {
		return outValue.Addr().Interface(), nil
	}
}

func deepCopy(src reflect.Value) (reflect.Value, error) {
	switch src.Kind() {
	case reflect.Chan, reflect.Func, reflect.UnsafePointer, reflect.Uintptr:
		return src, fmt.Errorf("cannot deep copy kind: %s", src.Kind())
	case reflect.Array:
		dst := reflect.New(src.Type())
		for i := 0; i < src.Len(); i++ {
			copyVal, err := deepCopy(src.Index(i))
			if err != nil {
				return src, err
			}
			dst.Elem().Index(i).Set(copyVal)
		}
		return dst.Elem(), nil
	case reflect.Interface:
		if src.IsNil() {
			return src, nil
		}
		return deepCopy(src.Elem())
	case reflect.Map:
		if src.IsNil() {
			return src, nil
		}
		dst := reflect.MakeMap(src.Type())
		for _, k := range src.MapKeys() {
			copyVal, err := deepCopy(src.MapIndex(k))
			if err != nil {
				return src, err
			}
			dst.SetMapIndex(k, copyVal)
		}
		return dst, nil
	case reflect.Ptr:
		if src.IsNil() {
			return src, nil
		}
		dst := reflect.New(src.Type().Elem())
		copyVal, err := deepCopy(src.Elem())
		if err != nil {
			return src, err
		}
		dst.Elem().Set(copyVal)
		return dst, nil
	case reflect.Slice:
		if src.IsNil() {
			return src, nil
		}
		dst := reflect.MakeSlice(src.Type(), 0, src.Len())
		for i := 0; i < src.Len(); i++ {
			copyVal, err := deepCopy(src.Index(i))
			if err != nil {
				return src, err
			}
			dst = reflect.Append(dst, copyVal)
		}
		return dst, nil
	case reflect.Struct:
		dst := reflect.New(src.Type())
		for i := 0; i < src.NumField(); i++ {
			if !dst.Elem().Field(i).CanSet() {
				// Can't set private fields. At this point, the best we can do is a
				// shallow copy. For example, time.Time is a value type with private
				// members that can be shallow copied.
				return src, nil
			}
			copyVal, err := deepCopy(src.Field(i))
			if err != nil {
				return src, err
			}
			dst.Elem().Field(i).Set(copyVal)
		}
		return dst.Elem(), nil

	default:
		// Value types like numbers, booleans, and strings.
		return src, nil
	}
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
