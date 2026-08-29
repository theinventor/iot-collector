package collector

import (
	"context"
	"encoding/json"
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

func TestConfigureSlotSendsValidatedFields(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(response http.ResponseWriter, request *http.Request) {
		if request.Method != http.MethodPut || request.URL.Path != "/api/v1/loggers/atom_lite_logger/slots/2" {
			t.Fatalf("request = %s %s", request.Method, request.URL.Path)
		}
		if request.Header.Get("Authorization") != "Bearer test-capability" {
			t.Fatalf("authorization = %q", request.Header.Get("Authorization"))
		}

		var slot VictronSlot
		if err := json.NewDecoder(request.Body).Decode(&slot); err != nil {
			t.Fatal(err)
		}
		if slot.Name != "Hardwired Charger" || slot.MACAddress != "aa:bb:cc:dd:ee:ff" || slot.BindKey != "00112233445566778899aabbccddeeff" {
			t.Fatalf("slot = %#v", slot)
		}

		response.Header().Set("Content-Type", "application/json")
		_, _ = response.Write([]byte(`{"ok":true,"logger":"atom_lite_logger","slot":{"position":2,"configured":true,"name":"Hardwired Charger"}}`))
	}))
	defer server.Close()

	client, err := New(server.URL, "test-capability", server.Client())
	if err != nil {
		t.Fatal(err)
	}
	result, err := client.ConfigureSlot(context.Background(), "atom_lite_logger", 2, VictronSlot{
		Name:             "Hardwired Charger",
		DeviceIdentifier: "hardwired_charger",
		MACAddress:       "aa:bb:cc:dd:ee:ff",
		BindKey:          "00112233445566778899aabbccddeeff",
	})
	if err != nil {
		t.Fatal(err)
	}
	if !result.Slot.Configured || result.Slot.Position != 2 {
		t.Fatalf("result = %#v", result)
	}
}

func TestLoggerConfigAndDiscoveriesEscapeLoggerName(t *testing.T) {
	requests := 0
	server := httptest.NewServer(http.HandlerFunc(func(response http.ResponseWriter, request *http.Request) {
		requests++
		response.Header().Set("Content-Type", "application/json")
		switch request.URL.Path {
		case "/api/v1/loggers/ATOM Lite/config":
			_, _ = response.Write([]byte(`{"ok":true,"logger":"atom_lite","slots":[]}`))
		case "/api/v1/loggers/ATOM Lite/discoveries":
			_, _ = response.Write([]byte(`{"ok":true,"logger":"atom_lite","discoveries":[]}`))
		default:
			t.Fatalf("path = %q", request.URL.Path)
		}
	}))
	defer server.Close()

	client, err := New(server.URL, "test-capability", server.Client())
	if err != nil {
		t.Fatal(err)
	}
	if _, err := client.LoggerConfig(context.Background(), "ATOM Lite"); err != nil {
		t.Fatal(err)
	}
	if _, err := client.Discoveries(context.Background(), "ATOM Lite"); err != nil {
		t.Fatal(err)
	}
	if requests != 2 {
		t.Fatalf("requests = %d", requests)
	}
}
