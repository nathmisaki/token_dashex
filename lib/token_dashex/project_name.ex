defmodule TokenDashex.ProjectName do
  @moduledoc """
  Derives a human-readable project name from the Claude Code `project_slug`
  plus the set of `cwd` values seen for that project.

  Mirrors the logic in the Python `token_dashboard` reference implementation
  so Elixir and Python dashboards display the same label for the same
  project — e.g. a slug `-Users-me-code-tupi-tupi-emsp` resolves to
  `tupi-emsp` (not the `-`-split fallback `emsp`) whenever any recorded cwd
  walks up to that slug.
  """

  @doc """
  Pick the prettiest project name given a list of cwds and the slug.

  Strategy (first win):

    1. Walk each cwd upward; if any ancestor encodes to `slug`, return that
       ancestor's basename.
    2. If no cwd matches, take the first non-nil cwd's trailing basename.
    3. Fall back to the slug's final `-` segment.
  """
  @spec best([String.t() | nil] | nil, String.t() | nil) :: String.t()
  def best(cwds, slug) do
    cwds = (cwds || []) |> Enum.reject(&(is_nil(&1) or &1 == ""))

    Enum.find_value(cwds, &walk_to_root(&1, slug)) ||
      from_single_cwd(List.first(cwds), slug || "")
  end

  @doc """
  Best-effort pretty name from one cwd + slug — same as `best/2` with a
  single-element cwd list.
  """
  @spec for_cwd(String.t() | nil, String.t() | nil) :: String.t()
  def for_cwd(cwd, slug), do: best([cwd], slug)

  defp from_single_cwd(nil, slug), do: slug_tail(slug)
  defp from_single_cwd("", slug), do: slug_tail(slug)

  defp from_single_cwd(cwd, slug) do
    walk_to_root(cwd, slug) || basename(cwd) || slug_tail(slug)
  end

  defp walk_to_root(cwd, slug) when is_binary(cwd) and is_binary(slug) and slug != "" do
    parts = cwd |> String.trim_trailing("/") |> String.split("/", trim: true)

    Enum.reduce_while(length(parts)..1//-1, nil, &match_ancestor(&1, &2, parts, slug))
  end

  defp walk_to_root(_, _), do: nil

  defp match_ancestor(i, _acc, parts, slug) do
    ancestor = "/" <> (parts |> Enum.take(i) |> Enum.join("/"))

    if encode_slug(ancestor) == slug do
      halt_with_name(Enum.at(parts, i - 1))
    else
      {:cont, nil}
    end
  end

  defp halt_with_name(name) when name in [nil, ""], do: {:halt, nil}
  defp halt_with_name(name), do: {:halt, name}

  defp encode_slug(path), do: String.replace(path, ~r{[:\\/ ]}, "-")

  defp basename(path) do
    tail =
      path
      |> String.trim_trailing("/")
      |> String.split("/", trim: true)
      |> List.last()

    if tail in [nil, ""], do: nil, else: tail
  end

  defp slug_tail(""), do: ""
  defp slug_tail(nil), do: ""

  defp slug_tail(slug) do
    slug
    |> String.split("-", trim: true)
    |> List.last()
    |> Kernel.||(slug)
  end
end
