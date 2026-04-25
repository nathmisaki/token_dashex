defmodule TokenDashex.PubSubTopics do
  @moduledoc """
  Centralised string constants for `Phoenix.PubSub` topics so producers and
  subscribers can't drift out of sync.
  """

  @scanner "scanner"
  @plan_changed "plan:changed"
  @tips_changed "tips:changed"

  @spec scanner() :: String.t()
  def scanner, do: @scanner

  @spec plan_changed() :: String.t()
  def plan_changed, do: @plan_changed

  @spec tips_changed() :: String.t()
  def tips_changed, do: @tips_changed
end
