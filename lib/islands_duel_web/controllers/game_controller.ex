defmodule IslandsDuelWeb.GameController do
  use IslandsDuelWeb, :controller

  import Phoenix.LiveView.Controller

  def create(conn, _params) do
    game_id = :crypto.strong_rand_bytes(12) |> Base.url_encode64(padding: false)
    redirect(conn, to: ~p"/games/#{game_id}")
  end

  def show(conn, %{"id" => id}) do
    live_render(conn, IslandsDuelWeb.GameLive, session: %{"game_id" => id})
  end
end
