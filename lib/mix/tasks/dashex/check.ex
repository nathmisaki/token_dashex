defmodule Mix.Tasks.Dashex.Check do
  @moduledoc """
  Run the project's quality harness:

    * `mix compile --warnings-as-errors`
    * `mix format --check-formatted`
    * `mix deps.unlock --check-unused`
    * `mix credo --strict` (also enforces module/dep boundaries via the
      `:boundary` compiler that runs during `mix compile`)
    * `mix dialyzer`
    * `mix coveralls` (test suite + coverage threshold from `coveralls.json`)

  Each step runs in its own `mix` subprocess so `preferred_cli_env`
  selections (e.g. `coveralls: :test`) take effect.

  Flags:
    --skip <step>     skip a step by name (repeatable)
    --only <step>     only run named steps (repeatable)
    --no-dialyzer     shorthand for `--skip dialyzer`
    --no-test         shorthand for `--skip test`

  Examples:
    mix dashex.check
    mix dashex.check --skip dialyzer
    mix dashex.check --only format --only credo
  """

  @shortdoc "Run quality harness (compile, format, credo, dialyzer, tests)"

  use Mix.Task
  use Boundary, check: [in: false, out: false]

  @steps [
    {"compile", "compile", ["--warnings-as-errors", "--force"]},
    {"format", "format", ["--check-formatted"]},
    {"deps.unused", "deps.unlock", ["--check-unused"]},
    {"credo", "credo", ["--strict"]},
    {"dialyzer", "dialyzer", []},
    {"test", "coveralls", []}
  ]

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [skip: :keep, only: :keep, dialyzer: :boolean, test: :boolean]
      )

    skip =
      Keyword.get_values(opts, :skip)
      |> add_if(opts[:dialyzer] == false, "dialyzer")
      |> add_if(opts[:test] == false, "test")

    only = Keyword.get_values(opts, :only)

    failures =
      Enum.reduce(@steps, [], fn {name, task, task_args}, acc ->
        cond do
          only != [] and name not in only ->
            acc

          name in skip ->
            log(:yellow, "==> skip #{name}")
            acc

          true ->
            log(:cyan, "==> #{name} (mix #{task} #{Enum.join(task_args, " ")})")

            case run_step(task, task_args) do
              0 -> acc
              code -> [{name, code} | acc]
            end
        end
      end)

    case Enum.reverse(failures) do
      [] ->
        log(:green, "==> harness passed")

      fails ->
        Mix.shell().error("\nharness failures:")

        Enum.each(fails, fn {name, code} ->
          Mix.shell().error("  - #{name} (exit #{code})")
        end)

        exit({:shutdown, 1})
    end
  end

  defp run_step(task, args) do
    Mix.shell().cmd("mix #{task} #{Enum.join(args, " ")}")
  end

  defp add_if(list, true, value), do: [value | list]
  defp add_if(list, _, _), do: list

  defp log(color, msg) do
    Mix.shell().info([apply(IO.ANSI, color, []), msg, IO.ANSI.reset()])
  end
end
