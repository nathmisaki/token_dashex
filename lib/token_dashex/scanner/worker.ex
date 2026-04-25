defmodule TokenDashex.Scanner.Worker do
  @moduledoc """
  GenServer that periodically scans the configured `~/.claude/projects` root
  for new JSONL bytes, parses them, and ingests the resulting records.

  Per-file state (mtime + byte offset) is persisted to the `file_states`
  table so a restart picks up where it left off. After every tick the worker
  broadcasts `{:scan_complete, summary}` on `PubSubTopics.scanner/0`.
  """

  use GenServer

  require Logger

  alias TokenDashex.{Ingest, PubSubTopics, Repo}
  alias TokenDashex.Scanner.{Dedup, Parser, Walker}
  alias TokenDashex.Schema.FileState

  @default_interval_ms 30_000

  defmodule Summary do
    @moduledoc false
    defstruct files: 0, records: 0, duration_ms: 0
  end

  ## Public API

  def start_link(opts) do
    {name, opts} = Keyword.pop(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Forces a synchronous scan and returns the summary. Primarily intended for
  CLI tasks and tests that want deterministic timing.
  """
  @spec tick(GenServer.server()) :: Summary.t()
  def tick(server \\ __MODULE__) do
    GenServer.call(server, :tick, 60_000)
  end

  ## Callbacks

  @impl true
  def init(opts) do
    state = %{
      root: Keyword.get(opts, :root, TokenDashex.Paths.projects_dir()),
      interval: Keyword.get(opts, :interval, @default_interval_ms),
      auto_tick: Keyword.get(opts, :auto_tick, true)
    }

    if state.auto_tick do
      schedule_tick(0)
    end

    {:ok, state}
  end

  @impl true
  def handle_info(:tick, state) do
    do_scan(state)
    schedule_tick(state.interval)
    {:noreply, state}
  end

  @impl true
  def handle_call(:tick, _from, state) do
    summary = do_scan(state)
    {:reply, summary, state}
  end

  ## Internals

  defp schedule_tick(interval), do: Process.send_after(self(), :tick, interval)

  defp do_scan(state) do
    started = System.monotonic_time(:millisecond)

    {files, records} =
      state.root
      |> Walker.walk()
      |> Enum.reduce({0, 0}, fn {path, slug}, {files_acc, records_acc} ->
        case scan_file(path, slug) do
          {:ok, count} -> {files_acc + 1, records_acc + count}
          :unchanged -> {files_acc, records_acc}
          {:error, reason} ->
            Logger.warning("scanner failed on #{path}: #{inspect(reason)}")
            {files_acc, records_acc}
        end
      end)

    duration_ms = System.monotonic_time(:millisecond) - started

    summary = %Summary{
      files: files,
      records: records,
      duration_ms: duration_ms
    }

    :telemetry.execute(
      [:token_dashex, :scanner, :tick],
      %{files: files, records: records, duration_ms: duration_ms},
      %{}
    )

    Phoenix.PubSub.broadcast(
      TokenDashex.PubSub,
      PubSubTopics.scanner(),
      {:scan_complete, summary}
    )

    summary
  end

  defp scan_file(path, slug) do
    with {:ok, %{mtime: mtime, size: size}} <- file_stat(path),
         %{offset: offset, prior_mtime: prior_mtime} <- load_state(path),
         true <- changed?(prior_mtime, mtime, offset, size) || :unchanged do
      records = read_new_records(path, offset, size)
      parsed_records = parse_and_dedup(records, slug)

      case Ingest.upsert_records(parsed_records) do
        {:ok, count} ->
          persist_state(path, mtime, size)
          {:ok, count}
      end
    else
      :unchanged -> :unchanged
      {:error, _} = error -> error
    end
  end

  defp file_stat(path) do
    case File.stat(path, time: :posix) do
      {:ok, %File.Stat{mtime: mtime, size: size}} ->
        {:ok, %{mtime: DateTime.from_unix!(mtime), size: size}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp load_state(path) do
    case Repo.get(FileState, path) do
      nil -> %{offset: 0, prior_mtime: nil}
      %FileState{byte_offset: offset, mtime: mtime} -> %{offset: offset, prior_mtime: mtime}
    end
  end

  defp changed?(nil, _new_mtime, _offset, _size), do: true
  defp changed?(_prior, _new, offset, size) when size > offset, do: true
  defp changed?(prior, new, _offset, _size), do: DateTime.compare(prior, new) != :eq

  defp read_new_records(path, offset, size) when size > offset do
    case File.open(path, [:read, :binary]) do
      {:ok, fd} ->
        try do
          :file.position(fd, offset)
          chunk = IO.binread(fd, size - offset)
          decode_lines(chunk)
        after
          File.close(fd)
        end

      {:error, _} ->
        []
    end
  end

  defp read_new_records(_path, _offset, _size), do: []

  defp decode_lines(chunk) do
    chunk
    |> String.split("\n", trim: true)
    |> Enum.map(fn line ->
      case Jason.decode(line) do
        {:ok, json} -> json
        _ -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp parse_and_dedup(records, slug) do
    records
    |> Enum.flat_map(fn rec ->
      case Parser.parse_record(rec, slug) do
        {:ok, parsed} -> [parsed]
        :skip -> []
      end
    end)
    |> Dedup.collapse()
  end

  defp persist_state(path, mtime, byte_offset) do
    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)
    mtime = ensure_usec(mtime)

    state = Repo.get(FileState, path) || %FileState{path: path}

    state
    |> FileState.changeset(%{
      path: path,
      mtime: mtime,
      byte_offset: byte_offset,
      last_scan_at: now
    })
    |> Repo.insert_or_update!()
  end

  defp ensure_usec(%DateTime{microsecond: {_, 6}} = dt), do: dt
  defp ensure_usec(%DateTime{} = dt), do: %{dt | microsecond: {0, 6}}
end
