defmodule TokenDashex.Tips.Rule do
  @moduledoc """
  Behaviour every tips rule implements. Rules are pure with respect to inputs:
  they read the current corpus via Ecto and return a list of tip maps. The
  dispatcher is responsible for filtering against dismissals.
  """

  @type tip :: %{
          key: String.t(),
          title: String.t(),
          body: String.t(),
          severity: :info | :warning
        }

  @callback evaluate() :: [tip]
end
