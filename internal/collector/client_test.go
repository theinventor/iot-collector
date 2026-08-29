package collector

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestStatusUsesBearerKey(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(response http.ResponseWriter, request *http.Request) {
		if request.URL.Path != "/api/v1/status" {
			t.Fatalf("path = %q", request.URL.Path)
		}
		if request.Header.Get("Authorization") != "Bearer test-capability" {
			t.Fatalf("authorization = %q", request.Header.Get("Authorization"))
		}
		response.Header().Set("Content-Type", "application/json")
		_, _ = response.Write([]byte(`{"ok":true,"collector":{"devices_count":2,"readings_count":12,"measurements_count":36}}`))
	}))
	defer server.Close()

	client, err := New(server.URL, "test-capability", server.Client())
	if err != nil {
		t.Fatal(err)
	}
	status, err := client.Status(context.Background())
	if err != nil {
		t.Fatal(err)
	}
	if status.Collector.DevicesCount != 2 || status.Collector.ReadingsCount != 12 {
		t.Fatalf("unexpected status: %#v", status)
	}
}

func TestReadingsBuildsRangeAndLimitQuery(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(response http.ResponseWriter, request *http.Request) {
		if request.URL.Path != "/api/v1/devices/rv_charger/readings" {
			t.Fatalf("path = %q", request.URL.Path)
		}
		if request.URL.Query().Get("range") != "7d" || request.URL.Query().Get("limit") != "25" {
			t.Fatalf("query = %q", request.URL.RawQuery)
		}
		response.Header().Set("Content-Type", "application/json")
		_, _ = response.Write([]byte(`{"ok":true,"device":"rv_charger","range":"7d","readings":[]}`))
	}))
	defer server.Close()

	client, err := New(server.URL, "test-capability", server.Client())
	if err != nil {
		t.Fatal(err)
	}
	readings, err := client.Readings(context.Background(), "rv_charger", "7d", 25)
	if err != nil {
		t.Fatal(err)
	}
	if readings.Range != "7d" {
		t.Fatalf("range = %q", readings.Range)
	}
}

func TestAPIErrorIncludesStatusAndMessage(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(response http.ResponseWriter, _ *http.Request) {
		response.Header().Set("Content-Type", "application/json")
		response.WriteHeader(http.StatusUnauthorized)
		_, _ = response.Write([]byte(`{"ok":false,"error":"unauthorized"}`))
	}))
	defer server.Close()

	client, err := New(server.URL, "wrong", server.Client())
	if err != nil {
		t.Fatal(err)
	}
	_, err = client.Status(context.Background())
	if err == nil || err.Error() != "collector returned 401: unauthorized" {
		t.Fatalf("error = %v", err)
	}
}
