defmodule TokenDashex.Pricing do
  @moduledoc """
  Loads `priv/pricing.json` and computes per-message USD cost.

  Rates are stored in `:persistent_term` because the JSON does not change at
  runtime and is read on every cost calculation. `reload!/0` exists for tests
  that need to round-trip new fixtures into the table.
  """

  @table :token_dashex_pricing

  @spec reload!() :: :ok
  def reload! do
    json =
      :token_dashex
      |> :code.priv_dir()
      |> Path.join("pricing.json")
      |> File.read!()
      |> Jason.decode!()

    :persistent_term.put(@table, json)
    :ok
  end

  @spec models() :: map()
  def models, do: get()["models"] || %{}

  @spec plans() :: map()
  def plans, do: get()["plans"] || %{}

  @spec plan(String.t()) :: map() | nil
  def plan(key), do: Map.get(plans(), key)

  @doc """
  Returns the USD cost for a single message's `usage` map.

  `usage` is the `message.usage` payload Claude Code writes to JSONL —
  `input_tokens`, `output_tokens`, `cache_creation_input_tokens`
  (or the split `cache_creation_5m_input_tokens` /
  `cache_creation_1h_input_tokens`), and `cache_read_input_tokens`.

  Unknown models fall through to the tier fallback table
  (opus/sonnet/haiku) inferred from the model id.
  """
  @spec cost_for(String.t() | nil, map()) :: float()
  def cost_for(model, %{} = usage) do
    rate = rate_for(model)
    {tokens_5m, tokens_1h} = cache_create_tokens(usage)

    Map.get(usage, "input_tokens", 0) * (rate["input"] || 0.0) / 1_000_000 +
      Map.get(usage, "output_tokens", 0) * (rate["output"] || 0.0) / 1_000_000 +
      tokens_5m * rate_create_5m(rate) / 1_000_000 +
      tokens_1h * rate_create_1h(rate) / 1_000_000 +
      Map.get(usage, "cache_read_input_tokens", 0) * (rate["cache_read"] || 0.0) / 1_000_000
  end

  defp rate_create_5m(rate), do: rate["cache_create_5m"] || rate["cache_create"] || 0.0
  defp rate_create_1h(rate), do: rate["cache_create_1h"] || rate_create_5m(rate)

  defp cache_create_tokens(usage) do
    case {Map.get(usage, "cache_creation_5m_input_tokens"),
          Map.get(usage, "cache_creation_1h_input_tokens")} do
      {nil, nil} -> {Map.get(usage, "cache_creation_input_tokens", 0), 0}
      {a, b} -> {a || 0, b || 0}
    end
  end

  defp rate_for(nil), do: %{}

  defp rate_for(model) do
    case Map.get(models(), model) do
      nil -> tier_fallback(model)
      rate -> rate
    end
  end

  defp tier_fallback(model) do
    fallbacks = get()["tier_fallback"] || %{}

    cond do
      String.contains?(model, "opus") -> Map.get(fallbacks, "opus", %{})
      String.contains?(model, "sonnet") -> Map.get(fallbacks, "sonnet", %{})
      String.contains?(model, "haiku") -> Map.get(fallbacks, "haiku", %{})
      true -> %{}
    end
  end

  defp get do
    case :persistent_term.get(@table, :missing) do
      :missing ->
        reload!()
        :persistent_term.get(@table)

      data ->
        data
    end
  end
end
