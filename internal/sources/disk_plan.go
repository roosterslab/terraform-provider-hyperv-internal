package sources

import (
	"context"
	"path/filepath"
	"strings"

	"github.com/hashicorp/terraform-plugin-framework/datasource"
	"github.com/hashicorp/terraform-plugin-framework/datasource/schema"
	"github.com/hashicorp/terraform-plugin-framework/types"

	"github.com/vinitsiriya/hyperv-management-api/terraform-provider-hypervapi-v2/internal/client"
)

var _ datasource.DataSource = &DiskPlanDataSource{}

func NewDiskPlanDataSource() datasource.DataSource { return &DiskPlanDataSource{} }

type DiskPlanDataSource struct{ cl *client.Client }

type diskPlanModel struct {
	ID           types.String `tfsdk:"id"`
	VMName       types.String `tfsdk:"vm_name"`
	Operation    types.String `tfsdk:"operation"`
	Purpose      types.String `tfsdk:"purpose"`
	SizeGB       types.Int64  `tfsdk:"size_gb"`
	CloneFrom    types.String `tfsdk:"clone_from"`
	PreferRoot   types.String `tfsdk:"prefer_root"`
	MinFreeGB    types.Int64  `tfsdk:"min_free_gb"`
	CoLocateWith types.String `tfsdk:"co_locate_with"`
	Ext          types.String `tfsdk:"ext"`

	Path           types.String   `tfsdk:"path"`
	Reason         types.String   `tfsdk:"reason"`
	MatchedRoot    types.String   `tfsdk:"matched_root"`
	NormalizedPath types.String   `tfsdk:"normalized_path"`
	Writable       types.Bool     `tfsdk:"writable"`
	FreeGBAfter    types.Int64    `tfsdk:"free_gb_after"`
	Host           types.String   `tfsdk:"host"`
	Warnings       []types.String `tfsdk:"warnings"`
}

func (d *DiskPlanDataSource) Metadata(_ context.Context, _ datasource.MetadataRequest, resp *datasource.MetadataResponse) {
	resp.TypeName = "hypervapiv2_disk_plan"
}

func (d *DiskPlanDataSource) Schema(_ context.Context, _ datasource.SchemaRequest, resp *datasource.SchemaResponse) {
	resp.Schema = schema.Schema{
		Attributes: map[string]schema.Attribute{
			"id":            schema.StringAttribute{Computed: true},
			"vm_name":       schema.StringAttribute{Required: true},
			"operation":     schema.StringAttribute{Required: true},
			"purpose":       schema.StringAttribute{Required: true},
			"size_gb":       schema.Int64Attribute{Optional: true},
			"clone_from":    schema.StringAttribute{Optional: true},
			"prefer_root":   schema.StringAttribute{Optional: true},
			"min_free_gb":   schema.Int64Attribute{Optional: true},
			"co_locate_with": schema.StringAttribute{Optional: true},
			"ext":           schema.StringAttribute{Optional: true},

			"path":            schema.StringAttribute{Computed: true},
			"reason":          schema.StringAttribute{Computed: true},
			"matched_root":    schema.StringAttribute{Computed: true},
			"normalized_path": schema.StringAttribute{Computed: true},
			"writable":        schema.BoolAttribute{Computed: true},
			"free_gb_after":   schema.Int64Attribute{Computed: true},
			"host":            schema.StringAttribute{Computed: true},
			"warnings":        schema.ListAttribute{ElementType: types.StringType, Computed: true},
		},
	}
}

func (d *DiskPlanDataSource) Configure(_ context.Context, req datasource.ConfigureRequest, _ *datasource.ConfigureResponse) {
	if req.ProviderData == nil { return }
	if c, ok := req.ProviderData.(*client.Client); ok { d.cl = c }
}

func (d *DiskPlanDataSource) Read(ctx context.Context, req datasource.ReadRequest, resp *datasource.ReadResponse) {
	cl := d.cl
	if cl == nil {
		resp.Diagnostics.AddError("provider not configured", "client missing")
		return
	}
	var data diskPlanModel
	resp.Diagnostics.Append(req.Config.Get(ctx, &data)...)
	if resp.Diagnostics.HasError() {
		return
	}
	in := client.DiskPlanRequest{
		VMName:    data.VMName.ValueString(),
		Operation: data.Operation.ValueString(),
		Purpose:   data.Purpose.ValueString(),
	}
	if !data.SizeGB.IsNull() { v := int(data.SizeGB.ValueInt64()); in.SizeGB = &v }
	if !data.CloneFrom.IsNull() { s := data.CloneFrom.ValueString(); in.CloneFrom = &s }
	if !data.PreferRoot.IsNull() { s := data.PreferRoot.ValueString(); in.PreferRoot = &s }
	if !data.MinFreeGB.IsNull() { v := int(data.MinFreeGB.ValueInt64()); in.MinFreeGB = &v }
	if !data.CoLocateWith.IsNull() { s := data.CoLocateWith.ValueString(); in.CoLocateWith = &s }
	if !data.Ext.IsNull() { s := data.Ext.ValueString(); in.Ext = &s }

	out, err := cl.PlanDisk(ctx, in)
	if err != nil {
		// Fallback: client-side suggestion using effective policy roots
		pol, perr := cl.Policy(ctx)
		if perr != nil {
			resp.Diagnostics.AddError("plan-disk failed", err.Error())
			return
		}
		// Prefer requested root if present; else first root
		var root string
		if !data.PreferRoot.IsNull() {
			pr := data.PreferRoot.ValueString()
			for _, r := range pol.Roots { if strings.EqualFold(r, pr) { root = r; break } }
		}
		if root == "" && len(pol.Roots) > 0 { root = pol.Roots[0] }
		if root == "" {
			resp.Diagnostics.AddError("plan-disk failed", "no allowed roots in effective policy")
			return
		}
		ext := "vhdx"
		if !data.Ext.IsNull() && data.Ext.ValueString() != "" { ext = data.Ext.ValueString() }
		p := filepath.Join(root, data.VMName.ValueString()+"."+ext)
		// Synthesize a minimal response compatible with the schema
		out = &client.DiskPlanResponse{
			Path:           p,
			Reason:         "fallback:client:first_allowed_root",
			MatchedRoot:    root,
			NormalizedPath: p,
			Writable:       true,
			FreeGBAfter:    0,
			Host:           "",
			Warnings:       []string{"server:plan-disk unavailable; used client fallback"},
		}
	}
	data.ID = types.StringValue(data.VMName.ValueString() + ":" + data.Purpose.ValueString())
	data.Path = types.StringValue(out.Path)
	data.Reason = types.StringValue(out.Reason)
	data.MatchedRoot = types.StringValue(out.MatchedRoot)
	data.NormalizedPath = types.StringValue(out.NormalizedPath)
	data.Writable = types.BoolValue(out.Writable)
	data.FreeGBAfter = types.Int64Value(int64(out.FreeGBAfter))
	data.Host = types.StringValue(out.Host)
	warns := make([]types.String, 0, len(out.Warnings))
	for _, w := range out.Warnings { warns = append(warns, types.StringValue(w)) }
	data.Warnings = warns

	resp.Diagnostics.Append(resp.State.Set(ctx, &data)...)
}
