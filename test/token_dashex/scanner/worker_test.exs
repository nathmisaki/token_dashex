defmodule TokenDashex.Scanner.WorkerTest do
  use TokenDashex.DataCase, async: false

  alias TokenDashex.JsonlFixtures
  alias TokenDashex.Scanner.Worker
  alias TokenDashex.Schema.{FileState, Message}

  setup do
    tmp = JsonlFixtures.write_to_tmp("simple_session.jsonl", "demo_proj")
    on_exit(fn -> File.rm_rf!(tmp) end)
    {:ok, root: tmp}
  end

  defp start_worker(root) do
    {:ok, pid} =
      Worker.start_link(
        name: :"worker_#{:erlang.unique_integer([:positive])}",
        root: root,
        auto_tick: false
      )

    Ecto.Adapters.SQL.Sandbox.allow(TokenDashex.Repo, self(), pid)
    pid
  end

  test "tick ingests fixture into the database and persists file state", %{root: root} do
    pid = start_worker(root)

    Phoenix.PubSub.subscribe(TokenDashex.PubSub, TokenDashex.PubSubTopics.scanner())

    summary = Worker.tick(pid)

    assert summary.files == 1
    assert summary.records > 0

    assert_receive {:scan_complete, ^summary}

    assert Repo.aggregate(Message, :count, :id) > 0
    assert [%FileState{byte_offset: offset}] = Repo.all(FileState)
    assert offset > 0
  end

  test "second tick on unchanged file is a no-op", %{root: root} do
    pid = start_worker(root)

    %{records: first} = Worker.tick(pid)
    assert first > 0

    %{records: second} = Worker.tick(pid)
    assert second == 0
  end

  test "missing root yields empty summary" do
    pid = start_worker("/totally/missing")

    summary = Worker.tick(pid)
    assert summary == %Worker.Summary{files: 0, records: 0, duration_ms: summary.duration_ms}
  end
end
