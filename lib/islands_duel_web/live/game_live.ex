defmodule IslandsDuelWeb.GameLive do
  use IslandsDuelWeb, :live_view

  alias IslandsDuel.{Game, Island, Coordinate, Board, GameSupervisor}

  @impl true
  def mount(_params, %{"game_id" => game_id, "current_user" => current_user}, socket) do
    username = current_user.name

    socket =
      socket
      |> assign(:game_id, game_id)
      |> assign(:username, username)
      |> assign(:player_role, nil)
      |> assign(:player1_name, nil)
      |> assign(:player2_name, nil)
      |> assign(:player_turn, nil)
      |> assign(:clicked_cells, MapSet.new())
      |> assign(:island_cells, MapSet.new())
      |> assign(:guess_results, %{})

    # Subscribe to PubSub topic for game broadcasts when connected
    if connected?(socket) do
      topic = "game:#{game_id}"
      Phoenix.PubSub.subscribe(IslandsDuel.PubSub, topic)

      # Join game: start if needed, add player, get role
      socket = join_game(socket, game_id, username)

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

    if clicked_player == opponent and opponent != nil and current_player != nil do
      row = String.to_integer(row)
      col = String.to_integer(col)
      game_id = socket.assigns.game_id
      game = Game.via_tuple(game_id)

      socket = load_game_state(socket, game_id)

      # Call Game.guess_coordinate - this will check rules and handle turn switching
      case Game.guess_coordinate(game, current_player, row, col) do
        {:hit, forested_island, win_status} ->
          # Hit! Update UI and broadcast
          socket =
            socket
            |> update_guess_result(opponent, row, col, :hit, forested_island, win_status)
            |> put_flash(:info, "Hit! #{if forested_island != :none, do: "Island #{forested_island} forested!", else: ""}")

          # Broadcast result to other player
          Phoenix.PubSub.broadcast(
            IslandsDuel.PubSub,
            game_topic(game_id),
            {:guess_result, %{
              player: current_player,
              opponent: opponent,
              row: row,
              col: col,
              result: :hit,
              forested_island: forested_island,
              win_status: win_status
            }}
          )

          socket =
            socket
            |> load_game_state(game_id)
            |> then(fn s ->
              if win_status == :win do
                put_flash(s, :success, "You won! Game over.")
              else
                s
              end
            end)

          {:noreply, socket}

        {:miss, :none, :no_win} ->
          # Miss! Update UI and broadcast
          socket =
            socket
            |> update_guess_result(opponent, row, col, :miss, :none, :no_win)
            |> put_flash(:info, "Miss!")

          # Broadcast result to other player
          Phoenix.PubSub.broadcast(
            IslandsDuel.PubSub,
            game_topic(game_id),
            {:guess_result, %{
              player: current_player,
              opponent: opponent,
              row: row,
              col: col,
              result: :miss,
              forested_island: :none,
              win_status: :no_win
            }}
          )

          socket = load_game_state(socket, game_id)
          {:noreply, socket}

        :error ->
          {:noreply, put_flash(socket, :error, "Not your turn or invalid move!")}
      end
    else
      # Ignore click on own board or invalid player
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:guess_result, %{player: player, opponent: opponent, row: row, col: col, result: result, forested_island: forested_island, win_status: win_status}}, socket) do
    # Get player names for display
    player_name = if player == :player1, do: socket.assigns.player1_name || "Player 1", else: socket.assigns.player2_name || "Player 2"

    # Update UI with guess result from other player
    socket =
      socket
      |> update_guess_result(opponent, row, col, result, forested_island, win_status)
      |> load_game_state(socket.assigns.game_id)
      |> put_flash(:info, "#{player_name} guessed (#{row}, #{col}) - #{if result == :hit, do: "Hit!", else: "Miss!"}")

    socket =
      if win_status == :win do
        put_flash(socket, :error, "#{player_name} won! Game over.")
      else
        socket
      end

    {:noreply, socket}
  end

  # Handle player added event from PubSub
  def handle_info({:player_added, %{username: username}}, socket) do
    socket =
      socket
      |> load_game_state(socket.assigns.game_id)
      |> put_flash(:info, "#{username} joined the game!")
    {:noreply, socket}
  end

  # Catch-all for any other messages
  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  # Join game logic (moved from GameChannel)
  defp join_game(socket, game_id, username) do
    game_pid = GenServer.whereis(Game.via_tuple(game_id))

    cond do
      # Game doesn't exist - start game and add player1
      game_pid == nil ->
        case GameSupervisor.start_game(game_id) do
          {:ok, _pid} ->
            case Game.add_player(Game.via_tuple(game_id), username) do
              :ok ->
                socket
                |> assign(:player_role, :player1)
                |> setup_player_islands(game_id, :player1)
                |> load_island_cells(game_id, :player1)
                |> load_game_state(game_id)

              :error ->
                assign(socket, :player_role, nil)
            end

          {:error, _reason} ->
            assign(socket, :player_role, nil)
        end

      # Game exists - try to add player or get existing role
      game_pid != nil ->
        case Game.get_state(game_id) do
          {:ok, state} ->
            # Check if user already in game
            cond do
              state.player1.name == username ->
                # User already in game as player1, allow rejoin
                socket
                |> assign(:player_role, :player1)
                |> setup_player_islands(game_id, :player1)
                |> load_island_cells(game_id, :player1)
                |> load_game_state(game_id)

              state.player2.name == username ->
                # User already in game as player2, allow rejoin
                socket
                |> assign(:player_role, :player2)
                |> setup_player_islands(game_id, :player2)
                |> load_island_cells(game_id, :player2)
                |> load_game_state(game_id)

              true ->
                # New player - try to add as player2
                case Game.add_player(Game.via_tuple(game_id), username) do
                  :ok ->
                    # Broadcast player added event
                    Phoenix.PubSub.broadcast(
                      IslandsDuel.PubSub,
                      game_topic(game_id),
                      {:player_added, %{username: username, player: :player2}}
                    )

                    socket
                    |> assign(:player_role, :player2)
                    |> setup_player_islands(game_id, :player2)
                    |> load_island_cells(game_id, :player2)
                    |> load_game_state(game_id)
                    |> put_flash(:info, "Joined game as Player 2")

                  :error ->
                    # Game is full or error
                    assign(socket, :player_role, nil)
                    |> put_flash(:error, "Unable to join game. Game may be full.")
                end
            end

          {:error, _} ->
            assign(socket, :player_role, nil)
            |> put_flash(:error, "Unable to get game state")
        end
    end
  end

  # Setup islands for a player
  defp setup_player_islands(socket, game_id, player) do
    setup_random_islands(game_id, player)
    socket
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
    row = :rand.uniform(11) - 1
    col = :rand.uniform(11) - 1

    case Game.position_island(game, player, island_key, row, col) do
      :ok -> :ok
      _ -> place_island_randomly(game, player, island_key, max_attempts - 1)
    end
  end

  defp place_island_randomly(_game, _player, _island_key, 0) do
    # Failed after max attempts, skip this island
    :ok
  end

  # Load game state and update player turn display
  defp load_game_state(socket, game_id) do
    case Game.get_state(game_id) do
      {:ok, state} ->
        player_turn = case state.rules.state do
          :player1_turn -> "#{state.player1.name || "Player 1"}'s turn"
          :player2_turn -> "#{state.player2.name || "Player 2"}'s turn"
          :game_over -> "Game over"
          :initialized -> "Setting up game..."
          :players_set -> "Setting up islands..."
          _ -> nil
        end
        socket
          |> assign(:player1_name, state.player1.name)
          |> assign(:player2_name, state.player2.name)
          |> assign(:player_turn, player_turn)
      {:error, _} ->
        socket
    end
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

  # Update UI with guess result
  defp update_guess_result(socket, opponent, row, col, result, _forested_island, _win_status) do
    cell_key = {opponent, row, col}

    # Update clicked_cells with result
    clicked_cells = MapSet.put(socket.assigns.clicked_cells, cell_key)

    socket =
      socket
      |> assign(:clicked_cells, clicked_cells)
      |> assign(:guess_results, Map.put(socket.assigns[:guess_results] || %{}, cell_key, result))

    socket
  end

  defp game_topic(game_id), do: "game:#{game_id}"

  # Helper function to get CSS class for guess cell
  def get_guess_cell_class(clicked_cells, guess_results, player, row, col) do
    cell_key = {player, row, col}

    if MapSet.member?(clicked_cells, cell_key) do
      guess_result = Map.get(guess_results || %{}, cell_key)
      if guess_result == :hit, do: "bg-red-500", else: "bg-gray-400"
    else
      ""
    end
  end
end
