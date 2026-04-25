defmodule TokenDashexWeb.SkillsLiveTest do
  use TokenDashexWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  setup do
    root = Path.join(System.tmp_dir!(), "tdx_skills_view_#{:erlang.unique_integer([:positive])}")
    File.mkdir_p!(Path.join([root, "skills", "alpha"]))
    File.write!(Path.join([root, "skills", "alpha", "SKILL.md"]), "alpha skill body")

    Application.put_env(:token_dashex, :skills_roots, [
      Path.join(root, "skills"),
      Path.join(root, "scheduled-tasks"),
      Path.join(root, "plugins")
    ])

    on_exit(fn ->
      File.rm_rf!(root)
      Application.delete_env(:token_dashex, :skills_roots)
    end)

    :ok
  end

  test "renders the discovered skill catalog", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/skills")
    assert html =~ "alpha"
  end
end
