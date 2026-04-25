defmodule TokenDashex do
  @moduledoc """
  TokenDashex keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """
  use Boundary,
    top_level?: true,
    deps: [],
    exports: [
      Analytics.ByModel,
      Analytics.Daily,
      Analytics.Overview,
      Analytics.Projects,
      Analytics.Prompts,
      Analytics.Sessions,
      Analytics.Tools,
      Ingest,
      Paths,
      Pricing,
      Pricing.Plan,
      PubSubTopics,
      Release,
      Repo,
      RuntimeConfig,
      Scanner.Dedup,
      Scanner.Parser,
      Scanner.Walker,
      Scanner.Worker,
      Schema.DismissedTip,
      Schema.FileState,
      Schema.Message,
      Schema.Plan,
      Schema.Tool,
      Skills,
      Tips,
      Tips.Rule
    ]
end
