defmodule IslandsDuelWeb.GameLive do
  use IslandsDuelWeb, :live_view

  alias IslandsDuel.{Game, Island, Coordinate, Board}

  @impl true
  def mount(_params, %{"game_id" => game_id, "current_user" => current_user}, socket) do
    username = current_user.name
    player_role = get_player_role(game_id, username)

    socket =
      socket
      |> assign(:game_id, game_id)
      |> assign(:username, username)
      |> assign(:player_role, player_role)
      |> assign(:clicked_cells, MapSet.new())
      |> assign(:island_cells, MapSet.new())

    # Subscribe to PubSub topic for game broadcasts when connected
    if connected?(socket) do
      topic = "game:#{game_id}"
      Phoenix.PubSub.subscribe(IslandsDuel.PubSub, topic)

      # Setup random islands for this player if not already set
      socket =
        if player_role do
          setup_random_islands(game_id, player_role)
          load_island_cells(socket, game_id, player_role)
        else
          socket
        end

      {:ok, socket}
    else
      {:ok, socket}
    end
  end

  @impl true
  def handle_event("cell_click", %{"player" => player, "row" => row, "col" => col}, socket) do
    clicked_player = String.to_atom(player)
    current_player = socket.assigns.player_role

    # Validate: only allow clicking opponent board
    opponent = case current_player do
      :player1 -> :player2
      :player2 -> :player1
      _ -> nil
    end

    if clicked_player == opponent and opponent != nil do
      row = String.to_integer(row)
      col = String.to_integer(col)

      # Broadcast via PubSub to all players in the game
      topic = "game:#{socket.assigns.game_id}"
      Phoenix.PubSub.broadcast(
        IslandsDuel.PubSub,
        topic,
        {:cell_clicked, %{player: clicked_player, row: row, col: col}}
      )

      {:noreply, socket}
    else
      # Ignore click on own board or invalid player
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:cell_clicked, %{player: player, row: row, col: col}}, socket) do
    cell_key = {player, row, col}

    clicked_cells =
      if MapSet.member?(socket.assigns.clicked_cells, cell_key) do
        MapSet.delete(socket.assigns.clicked_cells, cell_key)
      else
        MapSet.put(socket.assigns.clicked_cells, cell_key)
      end

    {:noreply, assign(socket, :clicked_cells, clicked_cells)}
  end

  defp get_player_role(game_id, username) do
    case Game.get_state(game_id) do
      {:ok, state} ->
        cond do
          state.player1.name == username -> :player1
          state.player2.name == username -> :player2
          true -> nil
        end
      {:error, :not_found} -> nil
    end
  end

  # Setup random islands for a player
  defp setup_random_islands(game_id, player) do
    game = Game.via_tuple(game_id)

    # Check if islands are already set
    case Game.get_state(game_id) do
      {:ok, state} ->
        board = Map.get(state, player).board
        if not Board.all_islands_positioned?(board) do
          # Place all 5 island types randomly
          Island.types()
          |> Enum.each(fn island_key ->
            place_island_randomly(game, player, island_key, 100)
          end)

          # Set islands after all are placed
          Game.set_islands(game, player)
        end
      {:error, _} ->
        :ok
    end
  end

  # Try to place an island at random positions until success
  defp place_island_randomly(game, player, island_key, max_attempts) when max_attempts > 0 do
    row = :rand.uniform(11) - 1  # 0-10
    col = :rand.uniform(11) - 1  # 0-10

    case Game.position_island(game, player, island_key, row, col) do
      :ok -> :ok
      _ -> place_island_randomly(game, player, island_key, max_attempts - 1)
    end
  end

  defp place_island_randomly(_game, _player, _island_key, 0) do
    # Failed after max attempts, skip this island
    :ok
  end

  # Load island cells from game state to display on board
  defp load_island_cells(socket, game_id, player) do
    case Game.get_state(game_id) do
      {:ok, state} ->
        board = Map.get(state, player).board

        island_cells =
          board
          |> Enum.reduce(MapSet.new(), fn {_island_key, island}, acc ->
            island.coordinates
            |> MapSet.to_list()
            |> Enum.reduce(acc, fn %Coordinate{row: row, col: col}, acc ->
              MapSet.put(acc, {player, row, col})
            end)
          end)

        assign(socket, :island_cells, island_cells)
      {:error, _} ->
        socket
    end
  end
end
