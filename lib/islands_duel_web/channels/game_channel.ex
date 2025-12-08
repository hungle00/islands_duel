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
            case Game.add_player(Game.via_tuple(game_id), username) do
              :ok -> {:ok, socket}
              :error -> {:error, %{reason: "Unable to add player"}}
            end
          {:error, reason} -> {:error, %{reason: inspect(reason)}}
        end

      # Game exists - try to add player
      game_pid != nil ->
        # Check if username already exists in the game
        case get_game_state(game_id) do
          {:ok, state} ->
            if state.player1.name == username or state.player2.name == username do
              # User already in game, allow rejoin
              {:ok, socket}
            else
              # Try to add as player2
              case Game.add_player(Game.via_tuple(game_id), username) do
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

  # Helper function to get game state
  defp get_game_state(game_id) do
    case GenServer.whereis(Game.via_tuple(game_id)) do
      nil -> {:error, :not_found}
      pid -> {:ok, :sys.get_state(pid)}
    end
  end

  # Note: "new_game" and "add_player" handlers are no longer needed
  # as the logic is now handled automatically in join/3
  # Keeping them for backward compatibility, but they are essentially no-ops
  @impl true
  def handle_in("new_game", _payload, socket) do
    # Game and player are already handled in join/3
    {:reply, :ok, socket}
  end

  def handle_in("add_player", _payload, socket) do
    # Player is already added in join/3
    {:reply, :ok, socket}
  end

  @impl true
  def handle_info({:broadcast_player_added, username}, socket) do
    broadcast!(socket, "player_added", %{message: "New player just joined: #{username}"})
    {:noreply, socket}
  end
end
