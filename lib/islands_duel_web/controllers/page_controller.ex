defmodule IslandsDuelWeb.PageController do
  use IslandsDuelWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
