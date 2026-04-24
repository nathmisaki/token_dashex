defmodule TokenDashexWeb.PageController do
  use TokenDashexWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
