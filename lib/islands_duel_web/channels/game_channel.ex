defmodule IslandsDuelWeb.GameChannel do
  use IslandsDuelWeb, :channel

  alias IslandsDuel.{Game, GameSupervisor}

  @impl true
  def join("game:" <> game_id, %{"username" => username}, socket) do
    socket = assign(socket, :game_id, game_id)
    socket = assign(socket, :username, username)

    game_pid = GenServer.whereis(Game.via_tuple(game_id))

    cond do
      # Game doesn't exist - start game and add player1
      game_pid == nil ->
        case GameSupervisor.start_game(game_id) do
          {:ok, _pid} ->
            case add_player(game_id, username) do
              :ok -> {:ok, socket}
              :error -> {:error, %{reason: "Unable to add player"}}
            end
          {:error, reason} -> {:error, %{reason: inspect(reason)}}
        end

      # Game exists - try to add player
      game_pid != nil ->
        # Check if username already exists in the game
        case Game.get_state(game_id) do
          {:ok, state} ->
            if state.player1.name == username or state.player2.name == username do
              # User already in game, allow rejoin
              {:ok, socket}
            else
              case add_player(game_id, username) do
                :ok ->
                  # Send message to self to broadcast after join completes
                  send(self(), {:broadcast_player_added, username})
                  {:ok, socket}
                :error ->
                  {:error, %{reason: "Unable to add player"}}
              end
            end
          {:error, _} ->
            {:error, %{reason: "Unable to get game state"}}
        end
    end
  end

  def join("game:" <> _game_id, _payload, _socket) do
    {:error, %{reason: "username is required"}}
  end

  defp add_player(game_id, username) do
    Game.add_player(Game.via_tuple(game_id), username)
  end

  @impl true
  def handle_in("cell_clicked", %{"player" => player, "row" => row, "col" => col}, socket) do
    # Broadcast to all players in the channel
    broadcast!(socket, "cell_clicked", %{
      player: player,
      row: row,
      col: col
    })
    {:noreply, socket}
  end

  @impl true
  def handle_info({:broadcast_player_added, username}, socket) do
    broadcast!(socket, "player_added", %{message: "New player just joined: #{username}"})
    {:noreply, socket}
  end

  # Catch-all for any other messages
  def handle_info(_msg, socket) do
    {:noreply, socket}
  end
end
