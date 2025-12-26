defmodule IslandsDuelWeb.Helpers.GameState do
  @moduledoc """
  Helper functions for formatting and displaying game state information.
  """

  @doc """
  Formats the game state atom into a displayable format with text and icon information.

  Returns a map with:
  - `:text` - The display text
  - `:icon` - The Heroicon name
  - `:color` - The color class for styling
  - `:show` - Whether to show this state
  """
  def display_state(game_state, player1_name \\ nil, player2_name \\ nil)

  def display_state(:player1_turn, player1_name, _player2_name) do
    %{
      text: "#{player1_name || "Player 1"}'s turn",
      icon: "hero-arrow-right-circle",
      color: "text-blue-600",
      show: true
    }
  end

  def display_state(:player2_turn, _player1_name, player2_name) do
    %{
      text: "#{player2_name || "Player 2"}'s turn",
      icon: "hero-arrow-right-circle",
      color: "text-purple-600",
      show: true
    }
  end

  def display_state(:game_over, _player1_name, _player2_name) do
    %{
      text: "Game Over",
      icon: "hero-flag",
      color: "text-red-600",
      show: true
    }
  end

  def display_state(:initialized, _player1_name, _player2_name) do
    %{
      text: "Setting up game...",
      icon: "hero-cog-6-tooth",
      color: "text-gray-500",
      show: true
    }
  end


  def display_state(:players_set, _player1_name, _player2_name) do
    %{
      text: "Setting up islands...",
      icon: "hero-map",
      color: "text-yellow-600",
      show: true
    }
  end

  def display_state(_other, _player1_name, _player2_name) do
    %{
      text: nil,
      icon: nil,
      color: nil,
      show: false
    }
  end
end
