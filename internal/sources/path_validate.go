package sources

import (
	"context"

	"github.com/hashicorp/terraform-plugin-framework/datasource"
	"github.com/hashicorp/terraform-plugin-framework/datasource/schema"
	"github.com/hashicorp/terraform-plugin-framework/types"

	"github.com/vinitsiriya/hyperv-management-api/terraform-provider-hypervapi-v2/internal/client"
)

var _ datasource.DataSource = &PathValidateDataSource{}

func NewPathValidateDataSource() datasource.DataSource { return &PathValidateDataSource{} }

type PathValidateDataSource struct{ cl *client.Client }

type pathValidateModel struct {
	ID             types.String `tfsdk:"id"`
	Path           types.String `tfsdk:"path"`
	Operation      types.String `tfsdk:"operation"`
	Ext            types.String `tfsdk:"ext"`
	Allowed        types.Bool   `tfsdk:"allowed"`
	MatchedRoot    types.String `tfsdk:"matched_root"`
	NormalizedPath types.String `tfsdk:"normalized_path"`
	Message        types.String `tfsdk:"message"`
	Violations     []types.String `tfsdk:"violations"`
}

func (d *PathValidateDataSource) Metadata(_ context.Context, _ datasource.MetadataRequest, resp *datasource.MetadataResponse) {
	resp.TypeName = "hypervapiv2_path_validate"
}

func (d *PathValidateDataSource) Schema(_ context.Context, _ datasource.SchemaRequest, resp *datasource.SchemaResponse) {
	resp.Schema = schema.Schema{
		Attributes: map[string]schema.Attribute{
			"id":        schema.StringAttribute{Computed: true},
			"path":      schema.StringAttribute{Required: true},
			"operation": schema.StringAttribute{Required: true},
			"ext":       schema.StringAttribute{Optional: true},

			"allowed":         schema.BoolAttribute{Computed: true},
			"matched_root":    schema.StringAttribute{Computed: true},
			"normalized_path": schema.StringAttribute{Computed: true},
			"message":         schema.StringAttribute{Computed: true},
			"violations":      schema.ListAttribute{ElementType: types.StringType, Computed: true},
		},
	}
}

func (d *PathValidateDataSource) Configure(_ context.Context, req datasource.ConfigureRequest, _ *datasource.ConfigureResponse) {
	if req.ProviderData == nil { return }
	if c, ok := req.ProviderData.(*client.Client); ok { d.cl = c }
}

func (d *PathValidateDataSource) Read(ctx context.Context, req datasource.ReadRequest, resp *datasource.ReadResponse) {
	cl := d.cl
	if cl == nil {
		resp.Diagnostics.AddError("provider not configured", "client missing")
		return
	}
	var data pathValidateModel
	resp.Diagnostics.Append(req.Config.Get(ctx, &data)...)
	if resp.Diagnostics.HasError() {
		return
	}
	in := client.PathValidateRequest{Path: data.Path.ValueString(), Operation: data.Operation.ValueString(), Ext: data.Ext.ValueString()}
	out, err := cl.ValidatePath(ctx, in)
	if err != nil {
		resp.Diagnostics.AddError("validate-path failed", err.Error())
		return
	}
	data.ID = types.StringValue(data.Path.ValueString())
	data.Allowed = types.BoolValue(out.Allowed)
	data.MatchedRoot = types.StringValue(out.MatchedRoot)
	data.NormalizedPath = types.StringValue(out.NormalizedPath)
	data.Message = types.StringValue(out.Message)
	viol := make([]types.String, 0, len(out.Violations))
	for _, v := range out.Violations { viol = append(viol, types.StringValue(v)) }
	data.Violations = viol
	resp.Diagnostics.Append(resp.State.Set(ctx, &data)...)
}
