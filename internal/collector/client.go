package collector

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"strings"
)

type Client struct {
	baseURL    string
	key        string
	httpClient *http.Client
}

type Status struct {
	OK        bool             `json:"ok"`
	Collector CollectorSummary `json:"collector"`
}

type CollectorSummary struct {
	DevicesCount      int     `json:"devices_count"`
	ReadingsCount     int     `json:"readings_count"`
	MeasurementsCount int     `json:"measurements_count"`
	LastReadingAt     *string `json:"last_reading_at"`
}

type Metric struct {
	Value      any    `json:"value"`
	Unit       string `json:"unit,omitempty"`
	RecordedAt string `json:"recorded_at,omitempty"`
}

type Device struct {
	Identifier    string            `json:"identifier"`
	Name          string            `json:"name"`
	LastSeenAt    *string           `json:"last_seen_at"`
	Online        bool              `json:"online"`
	ReadingsCount int               `json:"readings_count"`
	Latest        map[string]Metric `json:"latest"`
	MetricNames   []string          `json:"metric_names,omitempty"`
}

type DevicesResponse struct {
	OK      bool     `json:"ok"`
	Devices []Device `json:"devices"`
}

type DeviceResponse struct {
	OK     bool   `json:"ok"`
	Device Device `json:"device"`
}

type Reading struct {
	ID         int               `json:"id"`
	RecordedAt string            `json:"recorded_at"`
	Metrics    map[string]Metric `json:"metrics"`
}

type ReadingsResponse struct {
	OK       bool      `json:"ok"`
	Device   string    `json:"device"`
	Range    string    `json:"range"`
	Readings []Reading `json:"readings"`
}

type VictronSlot struct {
	Position         int    `json:"position"`
	Managed          bool   `json:"managed"`
	Configured       bool   `json:"configured"`
	DeviceIdentifier string `json:"device_identifier,omitempty"`
	Name             string `json:"name,omitempty"`
	MACAddress       string `json:"mac_address,omitempty"`
	BindKey          string `json:"bind_key,omitempty"`
	UpdatedAt        string `json:"updated_at,omitempty"`
}

type LoggerConfigResponse struct {
	OK        bool          `json:"ok"`
	Logger    string        `json:"logger"`
	UpdatedAt *string       `json:"updated_at"`
	Slots     []VictronSlot `json:"slots"`
}

type SlotResponse struct {
	OK     bool        `json:"ok"`
	Logger string      `json:"logger"`
	Slot   VictronSlot `json:"slot"`
}

type VictronDiscovery struct {
	MACAddress string `json:"mac_address"`
	ProductID  int    `json:"product_id"`
	RSSI       int    `json:"rssi"`
	LastSeenAt string `json:"last_seen_at"`
	Configured bool   `json:"configured"`
}

type DiscoveriesResponse struct {
	OK          bool               `json:"ok"`
	Logger      string             `json:"logger"`
	Discoveries []VictronDiscovery `json:"discoveries"`
}

func New(baseURL, key string, httpClient *http.Client) (*Client, error) {
	baseURL = strings.TrimRight(strings.TrimSpace(baseURL), "/")
	if baseURL == "" {
		return nil, fmt.Errorf("collector URL is required")
	}
	if _, err := url.ParseRequestURI(baseURL); err != nil {
		return nil, fmt.Errorf("invalid collector URL: %w", err)
	}
	if strings.TrimSpace(key) == "" {
		return nil, fmt.Errorf("collector key is required")
	}
	if httpClient == nil {
		httpClient = http.DefaultClient
	}

	return &Client{baseURL: baseURL, key: key, httpClient: httpClient}, nil
}

func (c *Client) Status(ctx context.Context) (Status, error) {
	var response Status
	err := c.get(ctx, "/api/v1/status", &response)
	return response, err
}

func (c *Client) Devices(ctx context.Context) (DevicesResponse, error) {
	var response DevicesResponse
	err := c.get(ctx, "/api/v1/devices", &response)
	return response, err
}

func (c *Client) Device(ctx context.Context, identifier string) (DeviceResponse, error) {
	var response DeviceResponse
	err := c.get(ctx, "/api/v1/devices/"+url.PathEscape(identifier), &response)
	return response, err
}

func (c *Client) Readings(ctx context.Context, identifier, telemetryRange string, limit int) (ReadingsResponse, error) {
	query := url.Values{}
	query.Set("range", telemetryRange)
	query.Set("limit", fmt.Sprintf("%d", limit))

	var response ReadingsResponse
	path := "/api/v1/devices/" + url.PathEscape(identifier) + "/readings?" + query.Encode()
	err := c.get(ctx, path, &response)
	return response, err
}

func (c *Client) LoggerConfig(ctx context.Context, logger string) (LoggerConfigResponse, error) {
	var response LoggerConfigResponse
	path := "/api/v1/loggers/" + url.PathEscape(logger) + "/config"
	err := c.get(ctx, path, &response)
	return response, err
}

func (c *Client) ConfigureSlot(ctx context.Context, logger string, position int, slot VictronSlot) (SlotResponse, error) {
	var response SlotResponse
	path := fmt.Sprintf("/api/v1/loggers/%s/slots/%d", url.PathEscape(logger), position)
	err := c.doJSON(ctx, http.MethodPut, path, slot, &response)
	return response, err
}

func (c *Client) ClearSlot(ctx context.Context, logger string, position int) (SlotResponse, error) {
	var response SlotResponse
	path := fmt.Sprintf("/api/v1/loggers/%s/slots/%d", url.PathEscape(logger), position)
	err := c.doJSON(ctx, http.MethodDelete, path, nil, &response)
	return response, err
}

func (c *Client) Discoveries(ctx context.Context, logger string) (DiscoveriesResponse, error) {
	var response DiscoveriesResponse
	path := "/api/v1/loggers/" + url.PathEscape(logger) + "/discoveries"
	err := c.get(ctx, path, &response)
	return response, err
}

func (c *Client) get(ctx context.Context, path string, target any) error {
	return c.doJSON(ctx, http.MethodGet, path, nil, target)
}

func (c *Client) doJSON(ctx context.Context, method, path string, body, target any) error {
	var requestBody *bytes.Reader
	if body == nil {
		requestBody = bytes.NewReader(nil)
	} else {
		encoded, err := json.Marshal(body)
		if err != nil {
			return fmt.Errorf("encode collector request: %w", err)
		}
		requestBody = bytes.NewReader(encoded)
	}

	request, err := http.NewRequestWithContext(ctx, method, c.baseURL+path, requestBody)
	if err != nil {
		return err
	}
	request.Header.Set("Authorization", "Bearer "+c.key)
	request.Header.Set("Accept", "application/json")
	if body != nil {
		request.Header.Set("Content-Type", "application/json")
	}

	response, err := c.httpClient.Do(request)
	if err != nil {
		return err
	}
	defer response.Body.Close()

	if response.StatusCode < 200 || response.StatusCode >= 300 {
		var apiError struct {
			Error string `json:"error"`
		}
		_ = json.NewDecoder(response.Body).Decode(&apiError)
		if apiError.Error == "" {
			apiError.Error = response.Status

		}
		return fmt.Errorf("collector returned %d: %s", response.StatusCode, apiError.Error)
	}

	if target == nil {
		return nil
	}
	if err := json.NewDecoder(response.Body).Decode(target); err != nil {
		return fmt.Errorf("decode collector response: %w", err)
	}
	return nil
}
