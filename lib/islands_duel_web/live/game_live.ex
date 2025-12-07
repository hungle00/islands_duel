defmodule IslandsDuelWeb.GameLive do
  use IslandsDuelWeb, :live_view

  def mount(_params, %{"game_id" => game_id, "current_user" => current_user}, socket) do
    username = current_user.name
    # {:ok, _pid} = IslandsDuel.GameSupervisor.start_game(username)
    {:ok, socket |> assign(:game_id, game_id) |> assign(:username, username)}
  end
end
