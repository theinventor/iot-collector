package collector

import (
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

func (c *Client) get(ctx context.Context, path string, target any) error {
	request, err := http.NewRequestWithContext(ctx, http.MethodGet, c.baseURL+path, nil)
	if err != nil {
		return err
	}
	request.Header.Set("Authorization", "Bearer "+c.key)
	request.Header.Set("Accept", "application/json")

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

	if err := json.NewDecoder(response.Body).Decode(target); err != nil {
		return fmt.Errorf("decode collector response: %w", err)
	}
	return nil
}
