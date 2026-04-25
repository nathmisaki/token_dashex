defmodule TokenDashex.Tips.Rule do
  @moduledoc """
  Behaviour every tips rule implements. Rules are pure with respect to inputs:
  they read the current corpus via Ecto and return a list of tip maps. The
  dispatcher is responsible for filtering against dismissals.
  """

  @type tip :: %{
          required(:key) => String.t(),
          required(:category) => String.t(),
          required(:title) => String.t(),
          required(:body) => String.t(),
          required(:severity) => :info | :warning,
          optional(:scope) => String.t()
        }

  @callback evaluate() :: [tip]
end
