defmodule IslandsDuelWeb.HomeLive do
  use IslandsDuelWeb, :live_view

  alias Phoenix.LiveView.JS

  @impl true
  def mount(_params, session, socket) do
    current_user = Map.get(session, "current_user")
    {:ok, assign(socket, current_user: current_user, show_join_modal: false)}
  end

  @impl true
  def handle_event("open_join_modal", _params, socket) do
    {:noreply, assign(socket, show_join_modal: true)}
  end

  @impl true
  def handle_event("close_join_modal", _params, socket) do
    {:noreply, assign(socket, show_join_modal: false)}
  end

  @impl true
  def handle_event("join_game", %{"join_game" => %{"game_id" => game_id}}, socket) do
    game_id = String.trim(game_id)

    if game_id == "" do
      {:noreply, put_flash(socket, :error, "Game ID cannot be empty")}
    else
      {:noreply,
       socket
       |> assign(show_join_modal: false)
       |> push_navigate(to: ~p"/games/#{game_id}")}
    end
  end

  def handle_event("join_game", _params, socket) do
    {:noreply, put_flash(socket, :error, "Game ID is required")}
  end
end
