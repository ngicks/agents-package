// Package loggerfactory builds an opt-in slog.Logger configured by two
// pflag.BoolFunc flags ("--log" and "--log-level") and registers those flags
// on a Cobra command's persistent flag set.
//
// Logging is opt-in: when neither flag is given, BuildLogger returns a logger
// backed by slog.DiscardHandler. The presence of either flag enables logging.
package loggerfactory

import (
	"fmt"
	"io"
	"log/slog"
	"os"
	"strings"

	"github.com/spf13/cobra"
)

const (
	LevelTrace = slog.Level(-8)
	LevelFatal = slog.Level(12)
)

// Config holds the logger configuration populated by the registered flags.
type Config struct {
	Enabled bool
	Format  string
	Level   slog.Level
}

// RegisterFlags registers "--log" and "--log-level" as persistent flags on cmd
// and returns a *Config that the flag callbacks populate during parsing.
//
// The defaults applied when a flag is given without a value are "json" for
// --log and "info" for --log-level. Both flag values are case-insensitive.
func RegisterFlags(cmd *cobra.Command) *Config {
	config := &Config{
		Format: "json",
		Level:  slog.LevelInfo,
	}
	f := cmd.PersistentFlags()

	f.BoolFunc("log", `enable logging; format "text" or "json" (case-insensitive; default "json")`, func(s string) error {
		config.Enabled = true
		switch v := strings.ToLower(s); v {
		case "true": // presence only
			return nil
		case "text", "json":
			config.Format = v
			return nil
		}
		return fmt.Errorf(`--log: must be "text" or "json" (case-insensitive), got %q`, s)
	})

	f.BoolFunc("log-level", `enable logging; level "trace" | "debug" | "info" | "warn" | "error" | "fatal" (case-insensitive; default "info")`, func(s string) error {
		config.Enabled = true
		switch strings.ToLower(s) {
		case "true": // presence only
			return nil
		case "trace":
			config.Level = LevelTrace
		case "debug":
			config.Level = slog.LevelDebug
		case "info":
			config.Level = slog.LevelInfo
		case "warn":
			config.Level = slog.LevelWarn
		case "error":
			config.Level = slog.LevelError
		case "fatal":
			config.Level = LevelFatal
		default:
			return fmt.Errorf(`--log-level: must be one of "trace", "debug", "info", "warn", "error", "fatal" (case-insensitive); got %q`, s)
		}
		return nil
	})

	return config
}

// BuildLogger constructs the slog.Logger described by config. When
// config.Enabled is false the logger discards all records.
//
// Output is written to os.Stderr. Pass BuildLoggerTo to redirect.
func BuildLogger(config *Config) *slog.Logger {
	return BuildLoggerTo(config, os.Stderr)
}

// BuildLoggerTo is BuildLogger with an explicit io.Writer destination.
func BuildLoggerTo(config *Config, w io.Writer) *slog.Logger {
	if !config.Enabled {
		return slog.New(slog.DiscardHandler)
	}
	opts := &slog.HandlerOptions{
		AddSource: true,
		Level:     config.Level,
	}
	var h slog.Handler
	switch config.Format {
	case "text":
		h = slog.NewTextHandler(w, opts)
	default: // "json"
		h = slog.NewJSONHandler(w, opts)
	}
	return slog.New(h)
}
