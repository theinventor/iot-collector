package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"net/http"
	"os"
	"sort"
	"strconv"
	"strings"
	"text/tabwriter"
	"time"

	"github.com/theinventor/iot-collector/internal/collector"
)

const defaultURL = "https://iot.sunflower-vacations.com"

func main() {
	os.Exit(run(os.Args[1:], os.Stdout, os.Stderr))
}

func run(args []string, stdout, stderr io.Writer) int {
	flags := flag.NewFlagSet("iotcollector", flag.ContinueOnError)
	flags.SetOutput(stderr)
	baseURL := flags.String("url", envOrDefault("IOT_COLLECTOR_URL", defaultURL), "collector base URL")
	key := flags.String("key", os.Getenv("IOT_COLLECTOR_KEY"), "collector capability key")
	jsonOutput := flags.Bool("json", false, "print raw JSON")
	telemetryRange := flags.String("range", "24h", "reading range: 1h, 6h, 24h, 7d, or 30d")
	limit := flags.Int("limit", 100, "maximum readings to return")
	flags.Usage = func() {
		fmt.Fprintln(stderr, "Usage: iotcollector [flags] <status|devices|latest|readings> [device]")
		flags.PrintDefaults()
	}

	if err := flags.Parse(args); err != nil {
		return 2
	}
	commandArgs := flags.Args()
	if len(commandArgs) == 0 {
		flags.Usage()
		return 2
	}

	client, err := collector.New(*baseURL, *key, &http.Client{Timeout: 15 * time.Second})
	if err != nil {
		fmt.Fprintln(stderr, "Error:", err)
		return 2
	}

	ctx := context.Background()
	switch commandArgs[0] {
	case "status":
		status, err := client.Status(ctx)
		if err != nil {
			return printError(stderr, err)
		}
		if *jsonOutput {
			return printJSON(stdout, status)
		}
		printStatus(stdout, status)
	case "devices":
		response, err := client.Devices(ctx)
		if err != nil {
			return printError(stderr, err)
		}
		if *jsonOutput {
			return printJSON(stdout, response)
		}
		printDevices(stdout, response.Devices)
	case "latest":
		identifier, ok := deviceArgument(commandArgs, stderr)
		if !ok {
			return 2
		}
		response, err := client.Device(ctx, identifier)
		if err != nil {
			return printError(stderr, err)
		}
		if *jsonOutput {
			return printJSON(stdout, response)
		}
		printLatest(stdout, response.Device)
	case "readings":
		identifier, ok := deviceArgument(commandArgs, stderr)
		if !ok {
			return 2
		}
		response, err := client.Readings(ctx, identifier, *telemetryRange, *limit)
		if err != nil {
			return printError(stderr, err)
		}
		if *jsonOutput {
			return printJSON(stdout, response)
		}
		printReadings(stdout, response.Readings)
	default:
		fmt.Fprintf(stderr, "Unknown command: %s\n", commandArgs[0])
		flags.Usage()
		return 2
	}

	return 0
}

func printStatus(output io.Writer, status collector.Status) {
	fmt.Fprintln(output, "Collector reachable")
	fmt.Fprintf(output, "Devices: %d\n", status.Collector.DevicesCount)
	fmt.Fprintf(output, "Readings: %d\n", status.Collector.ReadingsCount)
	fmt.Fprintf(output, "Measurements: %d\n", status.Collector.MeasurementsCount)
	if status.Collector.LastReadingAt != nil {
		fmt.Fprintf(output, "Last reading: %s\n", *status.Collector.LastReadingAt)
	} else {
		fmt.Fprintln(output, "Last reading: none")
	}
}

func printDevices(output io.Writer, devices []collector.Device) {
	writer := tabwriter.NewWriter(output, 0, 4, 2, ' ', 0)
	fmt.Fprintln(writer, "DEVICE\tNAME\tSTATE\tREADINGS\tLAST SEEN")
	for _, device := range devices {
		state := "idle"
		if device.Online {
			state = "online"
		}
		fmt.Fprintf(writer, "%s\t%s\t%s\t%d\t%s\n", device.Identifier, device.Name, state, device.ReadingsCount, stringValue(device.LastSeenAt))
	}
	_ = writer.Flush()
}

func printLatest(output io.Writer, device collector.Device) {
	fmt.Fprintf(output, "%s (%s)\n", device.Name, device.Identifier)
	metricNames := sortedKeys(device.Latest)
	for _, name := range metricNames {
		metric := device.Latest[name]
		fmt.Fprintf(output, "%s: %s", name, metricValue(metric))
		if metric.RecordedAt != "" {
			fmt.Fprintf(output, "  %s", metric.RecordedAt)
		}
		fmt.Fprintln(output)
	}
}

func printReadings(output io.Writer, readings []collector.Reading) {
	for _, reading := range readings {
		parts := make([]string, 0, len(reading.Metrics))
		for _, name := range sortedKeys(reading.Metrics) {
			parts = append(parts, name+"="+metricValue(reading.Metrics[name]))
		}
		fmt.Fprintf(output, "%s  %s\n", reading.RecordedAt, strings.Join(parts, "  "))
	}
}

func metricValue(metric collector.Metric) string {
	var value string
	switch typed := metric.Value.(type) {
	case float64:
		value = strconv.FormatFloat(typed, 'f', -1, 64)
	case nil:
		value = "-"
	default:
		value = fmt.Sprint(typed)
	}
	if metric.Unit != "" {
		return value + " " + metric.Unit
	}
	return value
}

func sortedKeys[T any](values map[string]T) []string {
	keys := make([]string, 0, len(values))
	for key := range values {
		keys = append(keys, key)
	}
	sort.Strings(keys)
	return keys
}

func printJSON(output io.Writer, value any) int {
	encoder := json.NewEncoder(output)
	encoder.SetIndent("", "  ")
	if err := encoder.Encode(value); err != nil {
		return printError(os.Stderr, err)
	}
	return 0
}

func printError(output io.Writer, err error) int {
	fmt.Fprintln(output, "Error:", err)
	return 1
}

func deviceArgument(args []string, stderr io.Writer) (string, bool) {
	if len(args) < 2 || strings.TrimSpace(args[1]) == "" {
		fmt.Fprintln(stderr, "Error: this command requires a device identifier")
		return "", false
	}
	return args[1], true
}

func envOrDefault(name, fallback string) string {
	if value := os.Getenv(name); value != "" {
		return value
	}
	return fallback
}

func stringValue(value *string) string {
	if value == nil {
		return "-"
	}
	return *value
}
