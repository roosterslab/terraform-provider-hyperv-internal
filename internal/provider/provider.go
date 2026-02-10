package provider

import (
	"context"
	"fmt"

	"github.com/hashicorp/terraform-plugin-framework/datasource"
	"github.com/hashicorp/terraform-plugin-framework/provider"
	"github.com/hashicorp/terraform-plugin-framework/provider/schema"
	"github.com/hashicorp/terraform-plugin-framework/resource"
	"github.com/hashicorp/terraform-plugin-framework/types"
	"github.com/hashicorp/terraform-plugin-log/tflog"

	"github.com/vinitsiriya/hyperv-management-api/terraform-provider-hypervapi-v2/internal/client"
	"github.com/vinitsiriya/hyperv-management-api/terraform-provider-hypervapi-v2/internal/resources"
	"github.com/vinitsiriya/hyperv-management-api/terraform-provider-hypervapi-v2/internal/sources"
)

// Ensure the implementation satisfies the expected interfaces.
var _ provider.Provider = &HyperVApiV2Provider{}

func New(version string) func() provider.Provider {
	return func() provider.Provider { return &HyperVApiV2Provider{version: version} }
}

// HyperVApiV2Provider is the provider implementation.
type HyperVApiV2Provider struct {
	version string
}

type providerModel struct {
	Endpoint            types.String `tfsdk:"endpoint"`
	Proxy               types.String `tfsdk:"proxy"`
	TimeoutSeconds      types.Int64  `tfsdk:"timeout_seconds"`
	EnforcePolicyPaths  types.Bool   `tfsdk:"enforce_policy_paths"`
	Strict              types.Bool   `tfsdk:"strict"`
	Auth                *authModel   `tfsdk:"auth"`
	Defaults            *defaults    `tfsdk:"defaults"`
	LogHTTP             types.Bool   `tfsdk:"log_http"`
}

type authModel struct {
	Method   types.String `tfsdk:"method"`
	Username types.String `tfsdk:"username"`
	Password types.String `tfsdk:"password"`
}

type defaults struct {
	CPU    types.Int64  `tfsdk:"cpu"`
	Memory types.String `tfsdk:"memory"`
	Disk   types.String `tfsdk:"disk"`
}

func (p *HyperVApiV2Provider) Metadata(_ context.Context, _ provider.MetadataRequest, resp *provider.MetadataResponse) {
	resp.TypeName = "hypervapiv2"
	resp.Version = p.version
}

func (p *HyperVApiV2Provider) Schema(_ context.Context, _ provider.SchemaRequest, resp *provider.SchemaResponse) {
	resp.Schema = schema.Schema{
		Description: "Policy-aware Terraform provider for Hyper-V Management API v2.",
		Attributes: map[string]schema.Attribute{
			"endpoint": schema.StringAttribute{Required: true, Description: "Base URL of the Hyper-V Management API v2."},
			"proxy":    schema.StringAttribute{Optional: true, Description: "Optional HTTP proxy."},
			"timeout_seconds": schema.Int64Attribute{Optional: true, Description: "Client timeout in seconds."},
			"enforce_policy_paths": schema.BoolAttribute{Optional: true, Description: "Fail plan if explicit paths violate policy."},
			"strict":               schema.BoolAttribute{Optional: true, Description: "Treat warnings as errors at plan-time."},
			"log_http":             schema.BoolAttribute{Optional: true, Description: "Enable verbose HTTP request/response logs (debug level)."},
		},
		Blocks: map[string]schema.Block{
			"auth": schema.SingleNestedBlock{
				Attributes: map[string]schema.Attribute{
					"method":   schema.StringAttribute{Required: true, Description: "Auth method: none | bearer | negotiate."},
					"username": schema.StringAttribute{Optional: true},
					"password": schema.StringAttribute{Optional: true, Sensitive: true},
				},
			},
			"defaults": schema.SingleNestedBlock{
				Attributes: map[string]schema.Attribute{
					"cpu":    schema.Int64Attribute{Optional: true},
					"memory": schema.StringAttribute{Optional: true},
					"disk":   schema.StringAttribute{Optional: true},
				},
			},
		},
	}
}

func (p *HyperVApiV2Provider) Configure(ctx context.Context, req provider.ConfigureRequest, resp *provider.ConfigureResponse) {
	var data providerModel
	resp.Diagnostics.Append(req.Config.Get(ctx, &data)...)
	if resp.Diagnostics.HasError() {
		return
	}

    cfg := client.Config{
        Endpoint:           data.Endpoint.ValueString(),
        Proxy:              data.Proxy.ValueString(),
        TimeoutSeconds:     300,
        // Policy enforcement is owned by the API server; provider does not enforce.
        EnforcePolicyPaths: false,
        Strict:             false,
        LogHTTP:            false,
    }
	if !data.TimeoutSeconds.IsNull() && !data.TimeoutSeconds.IsUnknown() { cfg.TimeoutSeconds = int(data.TimeoutSeconds.ValueInt64()) }
    // These settings are accepted for compatibility but are no-ops; API server enforces policy.
    if !data.EnforcePolicyPaths.IsNull() && !data.EnforcePolicyPaths.IsUnknown() { _ = data.EnforcePolicyPaths.ValueBool() }
    if !data.Strict.IsNull() && !data.Strict.IsUnknown() { _ = data.Strict.ValueBool() }
	if data.Auth != nil {
		cfg.Auth = client.AuthConfig{
			Method:   data.Auth.Method.ValueString(),
			Username: data.Auth.Username.ValueString(),
			Password: data.Auth.Password.ValueString(),
		}
	}
	if !data.LogHTTP.IsNull() && !data.LogHTTP.IsUnknown() { cfg.LogHTTP = data.LogHTTP.ValueBool() }
	if data.Defaults != nil {
		cfg.Defaults = &client.Defaults{
			CPU:    int(data.Defaults.CPU.ValueInt64()),
			Memory: data.Defaults.Memory.ValueString(),
			Disk:   data.Defaults.Disk.ValueString(),
		}
	}

	cl, err := client.New(cfg)
	if err != nil {
		resp.Diagnostics.AddError("client init failed", err.Error())
		return
	}
	// Expose client to resources and data sources
	resp.DataSourceData = cl
	resp.ResourceData = cl
	resp.Diagnostics.AddWarning("provider configured", fmt.Sprintf("endpoint=%s, auth=%s", cfg.Endpoint, cfg.Auth.Method))
	tflog.Info(ctx, "hypervapiv2 configured", map[string]any{"endpoint": cfg.Endpoint, "auth": cfg.Auth.Method})
}

func (p *HyperVApiV2Provider) Resources(_ context.Context) []func() resource.Resource {
	return []func() resource.Resource{
		resources.NewVMResource,
		resources.NewNetworkResource,
	}
}

func (p *HyperVApiV2Provider) DataSources(_ context.Context) []func() datasource.DataSource {
	return []func() datasource.DataSource{
		sources.NewDiskPlanDataSource,
		sources.NewPathValidateDataSource,
		sources.NewPolicyDataSource,
		sources.NewWhoAmIDataSource,
	}
}
