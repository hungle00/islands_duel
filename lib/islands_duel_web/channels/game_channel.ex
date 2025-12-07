defmodule IslandsDuelWeb.GameChannel do
  use IslandsDuelWeb, :channel

  alias IslandsDuel.{Game, GameSupervisor}

  @impl true
  def join("game:" <> _player, _payload, socket) do
    {:ok, socket}
  end

  # Channels can be used in a request/response fashion
  # by sending replies to requests from the client
  @impl true
  def handle_in("new_game", _payload, socket) do
    player = get_player1_name_from_socket(socket)
    IO.inspect player
    case GameSupervisor.start_game(player) do
      {:ok, _pid} -> {:reply, :ok, socket}
      {:error, reason} -> {:reply, {:error, %{reason: inspect(reason)}}, socket}
    end
  end

  def handle_in("add_player", player, socket) do
    case Game.add_player(via(socket.topic), player) do
      :ok ->
        broadcast! socket, "player_added", %{message: "New player just joined: " <> player}
        {:noreply, socket}
      {:error, reason} ->
        {:reply, {:error, %{reason: inspect(reason)}}, socket}
        :error -> {:reply, :error, socket}
    end
  end

  # Add authorization logic here as required.
  # defp authorized?(_payload) do
  #   true
  # end

  defp via("game:" <> player), do: Game.via_tuple(player)

  defp get_player1_name_from_socket(socket) do
    "game:" <> player1_name = socket.topic
    player1_name
  end
end
