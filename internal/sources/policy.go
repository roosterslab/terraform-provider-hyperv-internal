package sources

import (
	"context"

	"github.com/hashicorp/terraform-plugin-framework/datasource"
	"github.com/hashicorp/terraform-plugin-framework/datasource/schema"
	"github.com/hashicorp/terraform-plugin-framework/types"

	"github.com/vinitsiriya/hyperv-management-api/terraform-provider-hypervapi-v2/internal/client"
)

var _ datasource.DataSource = &PolicyDataSource{}

func NewPolicyDataSource() datasource.DataSource { return &PolicyDataSource{} }

type PolicyDataSource struct{ cl *client.Client }

type policyModel struct {
	ID         types.String   `tfsdk:"id"`
	Roots      []types.String `tfsdk:"roots"`
	Extensions []types.String `tfsdk:"extensions"`
	Message    types.String   `tfsdk:"message"`
}

func (d *PolicyDataSource) Metadata(_ context.Context, _ datasource.MetadataRequest, resp *datasource.MetadataResponse) {
	resp.TypeName = "hypervapiv2_policy"
}

func (d *PolicyDataSource) Schema(_ context.Context, _ datasource.SchemaRequest, resp *datasource.SchemaResponse) {
	resp.Schema = schema.Schema{
		Attributes: map[string]schema.Attribute{
			"id":         schema.StringAttribute{Computed: true},
			"roots":      schema.ListAttribute{ElementType: types.StringType, Computed: true},
			"extensions": schema.ListAttribute{ElementType: types.StringType, Computed: true},
			"message":    schema.StringAttribute{Computed: true},
		},
	}
}

func (d *PolicyDataSource) Configure(_ context.Context, req datasource.ConfigureRequest, _ *datasource.ConfigureResponse) {
	if req.ProviderData == nil { return }
	if c, ok := req.ProviderData.(*client.Client); ok { d.cl = c }
}

func (d *PolicyDataSource) Read(ctx context.Context, req datasource.ReadRequest, resp *datasource.ReadResponse) {
	cl := d.cl
	if cl == nil {
		resp.Diagnostics.AddError("provider not configured", "client missing")
		return
	}
	var data policyModel
	out, err := cl.Policy(ctx)
	if err != nil {
		resp.Diagnostics.AddError("policy fetch failed", err.Error())
		return
	}
	data.ID = types.StringValue("policy")
	roots := make([]types.String, 0, len(out.Roots))
	exts := make([]types.String, 0, len(out.Extensions))
	for _, r := range out.Roots { roots = append(roots, types.StringValue(r)) }
	for _, e := range out.Extensions { exts = append(exts, types.StringValue(e)) }
	data.Roots = roots
	data.Extensions = exts
	resp.Diagnostics.Append(resp.State.Set(ctx, &data)...)
}
