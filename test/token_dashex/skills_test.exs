defmodule TokenDashex.SkillsTest do
  use TokenDashex.DataCase, async: false

  alias TokenDashex.Skills
  alias TokenDashex.Schema.Message

  setup do
    root = Path.join(System.tmp_dir!(), "tdx_skills_#{:erlang.unique_integer([:positive])}")
    File.mkdir_p!(root)

    File.mkdir_p!(Path.join([root, "skills", "alpha"]))
    File.write!(Path.join([root, "skills", "alpha", "SKILL.md"]), "# Alpha skill content")

    File.mkdir_p!(Path.join([root, "plugins", "myplug", "skills", "beta"]))

    File.write!(
      Path.join([root, "plugins", "myplug", "skills", "beta", "SKILL.md"]),
      String.duplicate("body ", 100)
    )

    Application.put_env(:token_dashex, :skills_roots, [
      Path.join(root, "skills"),
      Path.join(root, "scheduled-tasks"),
      Path.join(root, "plugins")
    ])

    on_exit(fn ->
      File.rm_rf!(root)
      Application.delete_env(:token_dashex, :skills_roots)
    end)

    {:ok, root: root}
  end

  test "catalog/0 builds slug + size for each SKILL.md" do
    catalog = Skills.catalog()
    slugs = Enum.map(catalog, & &1.slug)

    assert "alpha" in slugs
    assert "myplug:beta" in slugs

    beta = Enum.find(catalog, &(&1.slug == "myplug:beta"))
    assert beta.est_tokens > 0
  end

  test "usage_breakdown/0 counts skill mentions in messages" do
    insert_message("m1", "user uses alpha skill in this message")
    insert_message("m2", "another mention of alpha")
    insert_message("m3", "no relevant mention here")

    breakdown = Skills.usage_breakdown()
    alpha_row = Enum.find(breakdown, &(&1.slug == "alpha"))

    assert alpha_row.invocations == 2
    assert alpha_row.est_tokens > 0
  end

  test "missing root yields empty catalog" do
    Application.put_env(:token_dashex, :skills_roots, ["/totally/missing"])
    assert Skills.catalog() == []
  end

  defp insert_message(id, text) do
    %Message{}
    |> Message.changeset(%{
      id: "s:#{id}",
      session_id: "s",
      message_id: id,
      project_slug: "demo",
      role: "user",
      timestamp: DateTime.utc_now(),
      prompt_text: text
    })
    |> Repo.insert!()
  end
end
