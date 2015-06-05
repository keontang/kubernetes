// Copyright 2015 anchnet-go authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package anchnet

import (
	"testing"
)

func TestRemoveWhitespaces(t *testing.T) {
	table := []struct {
		rawString      string
		expectedString string
	}{
		{
			rawString:      "I have space",
			expectedString: "Ihavespace",
		},
		{
			rawString:      "I have\t tab",
			expectedString: "Ihavetab",
		},
		{
			rawString: `I have new
line`,
			expectedString: "Ihavenewline",
		},
	}

	for _, item := range table {
		acutalString := RemoveWhitespaces(item.rawString)
		if item.expectedString != acutalString {
			t.Errorf("Expected string \n%v, but got \n%v", item.expectedString, acutalString)
		}
	}
}

// TestGenSignature tests that we generate correct signature.
func TestGenSignature(t *testing.T) {
	jsonPayload := RemoveWhitespaces(`
{
  "product": {
    "cloud": {
      "amount": 1,
      "vm": {
        "cpu": 1,
        "mem": 1024,
        "image_id": "centos65x64d",
        "name": "test",
        "mode": "system",
        "login_mode": "pwd",
        "password": "anchnet20150401"
      },
      "net0": true,
      "net1": [],
      "hd": [
        {
          "type": 0,
          "unit": "100",
          "name": "anchnet应用"
        },
        {
          "type": 0,
          "unit": "100",
          "name": "anchnet数据库"
        }
      ],
      "ip": {
        "bw": "5",
        "ip_group": "eipg-00000000"
      }
    }
  },
  "zone": "ac1",
  "token": "1HC4XSHVTSRVU5C89NP4",
  "action": "RunInstances"
}
`)

	secret := "r3ak4XcBlM3zclK5turz1I3DjclK3Lk098Y4HDHo"
	// The result given in API doc is wrong:
	// "c37797da5d2747f68b8bbb9e0ad0d6da08132c3b66ceb48c3a491311a7bd080d"
	expectedSignature := "f45022c0f5b1da37dd53d2983b5cf2d487603ad48b88adae942297aa570ffd18"
	acutalSignature := GenSignature([]byte(jsonPayload), []byte(secret))

	if expectedSignature != acutalSignature {
		t.Errorf("Expected signature \n%v, but got \n%v", expectedSignature, acutalSignature)
	}
}
