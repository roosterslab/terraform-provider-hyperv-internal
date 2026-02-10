package sources

import (
	"context"

	"github.com/hashicorp/terraform-plugin-framework/datasource"
	"github.com/hashicorp/terraform-plugin-framework/datasource/schema"
	"github.com/hashicorp/terraform-plugin-framework/types"

	"github.com/vinitsiriya/hyperv-management-api/terraform-provider-hypervapi-v2/internal/client"
)

var _ datasource.DataSource = &WhoAmIDataSource{}

func NewWhoAmIDataSource() datasource.DataSource { return &WhoAmIDataSource{} }

type WhoAmIDataSource struct{ cl *client.Client }

type whoamiModel struct {
	ID     types.String   `tfsdk:"id"`
	User   types.String   `tfsdk:"user"`
	Domain types.String   `tfsdk:"domain"`
	Sid    types.String   `tfsdk:"sid"`
	Groups []types.String `tfsdk:"groups"`
}

func (d *WhoAmIDataSource) Metadata(_ context.Context, _ datasource.MetadataRequest, resp *datasource.MetadataResponse) {
	resp.TypeName = "hypervapiv2_whoami"
}

func (d *WhoAmIDataSource) Schema(_ context.Context, _ datasource.SchemaRequest, resp *datasource.SchemaResponse) {
	resp.Schema = schema.Schema{
		Attributes: map[string]schema.Attribute{
			"id":     schema.StringAttribute{Computed: true},
			"user":   schema.StringAttribute{Computed: true},
			"domain": schema.StringAttribute{Computed: true},
			"sid":    schema.StringAttribute{Computed: true},
			"groups": schema.ListAttribute{ElementType: types.StringType, Computed: true},
		},
	}
}

func (d *WhoAmIDataSource) Configure(_ context.Context, req datasource.ConfigureRequest, _ *datasource.ConfigureResponse) {
	if req.ProviderData == nil { return }
	if c, ok := req.ProviderData.(*client.Client); ok { d.cl = c }
}

func (d *WhoAmIDataSource) Read(ctx context.Context, req datasource.ReadRequest, resp *datasource.ReadResponse) {
	cl := d.cl
	if cl == nil {
		resp.Diagnostics.AddError("provider not configured", "client missing")
		return
	}
	var data whoamiModel
	out, err := cl.WhoAmI(ctx)
	if err != nil {
		resp.Diagnostics.AddError("whoami failed", err.Error())
		return
	}
	data.ID = types.StringValue(out.User)
	data.User = types.StringValue(out.User)
	data.Domain = types.StringValue(out.Domain)
	data.Sid = types.StringValue(out.SID)
	groups := make([]types.String, 0, len(out.Groups))
	for _, g := range out.Groups { groups = append(groups, types.StringValue(g)) }
	data.Groups = groups
	resp.Diagnostics.Append(resp.State.Set(ctx, &data)...)
}
