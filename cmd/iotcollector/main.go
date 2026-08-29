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
		fmt.Fprintln(stderr, "Usage: iotcollector [flags] <command> [arguments]")
		fmt.Fprintln(stderr, "Commands: status, devices, latest, readings, config, discoveries, configure, clear")
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
	case "config":
		logger, ok := deviceArgument(commandArgs, stderr)
		if !ok {
			return 2
		}
		response, err := client.LoggerConfig(ctx, logger)
		if err != nil {
			return printError(stderr, err)
		}
		if *jsonOutput {
			return printJSON(stdout, response)
		}
		printLoggerConfig(stdout, response)
	case "discoveries":
		logger, ok := deviceArgument(commandArgs, stderr)
		if !ok {
			return 2
		}
		response, err := client.Discoveries(ctx, logger)
		if err != nil {
			return printError(stderr, err)
		}
		if *jsonOutput {
			return printJSON(stdout, response)
		}
		printDiscoveries(stdout, response)
	case "configure":
		logger, position, slot, ok := configureArguments(commandArgs[1:], stderr)
		if !ok {
			return 2
		}
		response, err := client.ConfigureSlot(ctx, logger, position, slot)
		if err != nil {
			return printError(stderr, err)
		}
		if *jsonOutput {
			return printJSON(stdout, response)
		}
		fmt.Fprintf(stdout, "Configured slot %d: %s (%s) at %s\n", response.Slot.Position, response.Slot.Name, response.Slot.DeviceIdentifier, response.Slot.MACAddress)
	case "clear":
		logger, position, ok := loggerSlotArguments(commandArgs[1:], stderr)
		if !ok {
			return 2
		}
		response, err := client.ClearSlot(ctx, logger, position)
		if err != nil {
			return printError(stderr, err)
		}
		if *jsonOutput {
			return printJSON(stdout, response)
		}
		fmt.Fprintf(stdout, "Cleared slot %d on %s\n", position, response.Logger)
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

func printLoggerConfig(output io.Writer, response collector.LoggerConfigResponse) {
	fmt.Fprintf(output, "Logger: %s\n", response.Logger)
	writer := tabwriter.NewWriter(output, 0, 4, 2, ' ', 0)
	fmt.Fprintln(writer, "SLOT\tSTATE\tDEVICE\tNAME\tMAC\tBIND KEY")
	for _, slot := range response.Slots {
		if !slot.Managed {
			fmt.Fprintf(writer, "%d\tunmanaged\t-\t-\t-\t-\n", slot.Position)
			continue
		}
		if !slot.Configured {
			fmt.Fprintf(writer, "%d\tdisabled\t-\t-\t-\t-\n", slot.Position)
			continue
		}
		fmt.Fprintf(writer, "%d\tconfigured\t%s\t%s\t%s\tconfigured\n", slot.Position, slot.DeviceIdentifier, slot.Name, slot.MACAddress)
	}
	_ = writer.Flush()
}

func printDiscoveries(output io.Writer, response collector.DiscoveriesResponse) {
	fmt.Fprintf(output, "Logger: %s\n", response.Logger)
	writer := tabwriter.NewWriter(output, 0, 4, 2, ' ', 0)
	fmt.Fprintln(writer, "MAC\tPRODUCT\tRSSI\tSTATE\tLAST SEEN")
	for _, discovery := range response.Discoveries {
		state := "unconfigured"
		if discovery.Configured {
			state = "configured"
		}
		fmt.Fprintf(writer, "%s\t0x%04X\t%d dBm\t%s\t%s\n", discovery.MACAddress, discovery.ProductID, discovery.RSSI, state, discovery.LastSeenAt)
	}
	_ = writer.Flush()
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

func configureArguments(args []string, stderr io.Writer) (string, int, collector.VictronSlot, bool) {
	flags := flag.NewFlagSet("configure", flag.ContinueOnError)
	flags.SetOutput(stderr)
	name := flags.String("name", "", "display name")
	device := flags.String("device", "", "stable device identifier; defaults to the normalized name")
	mac := flags.String("mac", "", "Victron Bluetooth MAC address")
	bindKey := flags.String("bind-key", "", "32-character Victron advertisement key")
	flags.Usage = func() {
		fmt.Fprintln(stderr, "Usage: iotcollector configure --name NAME --mac MAC --bind-key KEY [--device ID] LOGGER SLOT")
		flags.PrintDefaults()
	}
	if err := flags.Parse(args); err != nil {
		return "", 0, collector.VictronSlot{}, false
	}

	logger, position, ok := loggerSlotArguments(flags.Args(), stderr)
	if !ok {
		flags.Usage()
		return "", 0, collector.VictronSlot{}, false
	}
	if strings.TrimSpace(*name) == "" || strings.TrimSpace(*mac) == "" || strings.TrimSpace(*bindKey) == "" {
		fmt.Fprintln(stderr, "Error: --name, --mac, and --bind-key are required")
		flags.Usage()
		return "", 0, collector.VictronSlot{}, false
	}

	return logger, position, collector.VictronSlot{
		DeviceIdentifier: strings.TrimSpace(*device),
		Name:             strings.TrimSpace(*name),
		MACAddress:       strings.ToLower(strings.ReplaceAll(strings.TrimSpace(*mac), "-", ":")),
		BindKey:          strings.ToLower(strings.TrimSpace(*bindKey)),
	}, true
}

func loggerSlotArguments(args []string, stderr io.Writer) (string, int, bool) {
	if len(args) != 2 || strings.TrimSpace(args[0]) == "" {
		fmt.Fprintln(stderr, "Error: this command requires a logger identifier and slot number")
		return "", 0, false
	}
	position, err := strconv.Atoi(args[1])
	if err != nil || position < 1 || position > 3 {
		fmt.Fprintln(stderr, "Error: slot must be 1, 2, or 3")
		return "", 0, false
	}
	return args[0], position, true
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
