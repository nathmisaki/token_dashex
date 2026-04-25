defmodule TokenDashex.Scanner.WalkerTest do
  use ExUnit.Case, async: true

  alias TokenDashex.Scanner.Walker

  setup do
    root = Path.join(System.tmp_dir!(), "tdx_walk_#{:erlang.unique_integer([:positive])}")
    File.mkdir_p!(root)

    on_exit(fn -> File.rm_rf!(root) end)

    {:ok, root: root}
  end

  test "walks subdirectories and pairs each jsonl with a slug", %{root: root} do
    a_path = Path.join([root, "project_a", "sess1.jsonl"])
    b_path = Path.join([root, "project_b", "nested", "sess2.jsonl"])

    File.mkdir_p!(Path.dirname(a_path))
    File.mkdir_p!(Path.dirname(b_path))
    File.write!(a_path, "{}\n")
    File.write!(b_path, "{}\n")

    entries = Walker.walk(root) |> Enum.sort()

    assert [{^a_path, "project_a"}, {^b_path, "project_b--nested"}] = entries
  end

  test "returns empty for missing roots" do
    assert Walker.walk("/totally/missing/path") == []
  end

  test "ignores non-jsonl files", %{root: root} do
    File.write!(Path.join(root, "x.txt"), "not jsonl")
    File.mkdir_p!(Path.join(root, "p"))
    File.write!(Path.join([root, "p", "real.jsonl"]), "{}\n")

    entries = Walker.walk(root)
    assert length(entries) == 1
  end
end
