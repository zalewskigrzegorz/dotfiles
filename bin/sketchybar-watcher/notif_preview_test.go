package main

import (
	"os"
	"strings"
	"testing"

	"howett.net/plist"
)

// TestParseNotifBlob_CleanFixture: the captured real-world blob from the
// current macOS NotificationCenter must decode and yield non-empty fields.
func TestParseNotifBlob_CleanFixture(t *testing.T) {
	b, err := os.ReadFile("testdata/notif_sample_clean.bin")
	if err != nil {
		t.Fatalf("read fixture: %v", err)
	}
	title, body, err := parseNotifBlob(b)
	if err != nil {
		t.Fatalf("parseNotifBlob on clean fixture: %v", err)
	}
	if title == "" && body == "" {
		t.Fatalf("expected non-empty title or body, got both empty")
	}
}

// TestParseNotifBlob_ArrayBody: regression — after a macOS update some
// notifications encode req.body / req.titl / req.subt as a plist ARRAY of
// strings instead of a single string. The previous struct typed these as
// string and Unmarshal returned a type-mismatch error, which the poller
// treated as fatal (notifEnabled=false → permanent shutdown). The decoder
// must now tolerate array-valued fields and join them into a single string.
func TestParseNotifBlob_ArrayBody(t *testing.T) {
	data := map[string]interface{}{
		"app":  "com.example.app",
		"date": 0.0,
		"req": map[string]interface{}{
			"titl": "Header",
			"body": []interface{}{"line one", "line two"},
			"subt": "",
		},
		"styl": 0,
	}
	b, err := plist.Marshal(data, plist.BinaryFormat)
	if err != nil {
		t.Fatalf("marshal synthetic blob: %v", err)
	}
	title, body, err := parseNotifBlob(b)
	if err != nil {
		t.Fatalf("array-valued field must not error: %v", err)
	}
	if title != "Header" {
		t.Fatalf("title = %q, want %q", title, "Header")
	}
	if !strings.Contains(body, "line one") || !strings.Contains(body, "line two") {
		t.Fatalf("body should contain both array elements, got %q", body)
	}
}

// TestParseNotifBlob_ArrayTitle: same as above but the TITLE is the array.
func TestParseNotifBlob_ArrayTitle(t *testing.T) {
	data := map[string]interface{}{
		"app":  "com.example.app",
		"date": 0.0,
		"req": map[string]interface{}{
			"titl": []interface{}{"part-a", "part-b"},
			"body": "plain body",
			"subt": "",
		},
		"styl": 0,
	}
	b, err := plist.Marshal(data, plist.BinaryFormat)
	if err != nil {
		t.Fatalf("marshal synthetic blob: %v", err)
	}
	title, _, err := parseNotifBlob(b)
	if err != nil {
		t.Fatalf("array-valued title must not error: %v", err)
	}
	if !strings.Contains(title, "part-a") || !strings.Contains(title, "part-b") {
		t.Fatalf("title should contain both array parts, got %q", title)
	}
}
