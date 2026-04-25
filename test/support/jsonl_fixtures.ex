defmodule TokenDashex.JsonlFixtures do
  @moduledoc """
  Test helpers for loading hand-crafted JSONL fixtures used by the scanner
  test suite.
  """

  @root "test/fixtures/jsonl"

  @spec path(String.t()) :: String.t()
  def path(name), do: Path.join(@root, name)

  @spec stream(String.t()) :: Enumerable.t()
  def stream(name) do
    name
    |> path()
    |> File.stream!()
    |> Stream.map(&(&1 |> String.trim_trailing() |> Jason.decode!()))
  end

  @doc """
  Returns the absolute path to a temp directory containing a single copy of
  fixture `name`. The caller owns cleanup.
  """
  @spec write_to_tmp(String.t(), String.t()) :: String.t()
  def write_to_tmp(name, project_slug) do
    tmp = Path.join(System.tmp_dir!(), "tdx_fixtures_#{:erlang.unique_integer([:positive])}")
    project = Path.join(tmp, project_slug)
    File.mkdir_p!(project)
    dest = Path.join(project, name)
    File.cp!(path(name), dest)
    tmp
  end
end
