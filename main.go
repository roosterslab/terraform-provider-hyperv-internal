package main

import (
	"context"
	"flag"
	"log"

	"github.com/hashicorp/terraform-plugin-framework/providerserver"
	"github.com/hashicorp/terraform-plugin-log/tflog"

	"github.com/vinitsiriya/hyperv-management-api/terraform-provider-hypervapi-v2/internal/provider"
)

var (
	// Set via -ldflags at build time
	version = "dev"
)

func main() {
	var debug bool
	flag.BoolVar(&debug, "debug", false, "Set to true to run the provider with debug mode enabled.")
	flag.Parse()

	ctx := context.Background()
	tflog.Info(ctx, "Starting hypervapiv2 provider", map[string]any{"version": version})

	opts := providerserver.ServeOpts{
		Address: "registry.terraform.io/vinitsiriya/hypervapiv2",
		Debug:   debug,
	}

	if err := providerserver.Serve(ctx, provider.New(version), opts); err != nil {
		log.Fatal(err)
	}
}
