defmodule TokenDashex.Schema.FileStateTest do
  use TokenDashex.DataCase, async: false

  alias TokenDashex.Schema.FileState

  test "valid changeset round-trips" do
    now = DateTime.utc_now()

    {:ok, _} =
      %FileState{}
      |> FileState.changeset(%{
        path: "/tmp/x.jsonl",
        mtime: now,
        byte_offset: 1024,
        last_scan_at: now
      })
      |> Repo.insert()

    assert %FileState{byte_offset: 1024} = Repo.get(FileState, "/tmp/x.jsonl")
  end

  test "rejects negative byte_offset" do
    changeset =
      FileState.changeset(%FileState{}, %{
        path: "/tmp/x.jsonl",
        mtime: DateTime.utc_now(),
        byte_offset: -1,
        last_scan_at: DateTime.utc_now()
      })

    refute changeset.valid?
    assert %{byte_offset: _} = errors_on(changeset)
  end
end
