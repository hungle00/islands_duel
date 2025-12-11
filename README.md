# Islands Duel

Islands Duel is a two-player strategy game built with Phoenix LiveView. Players place islands on their boards and take turns guessing coordinates on their opponent's board to find and "forest" all of the opponent's islands. The first player to forest all of their opponent's islands wins.

## Features

- **Real-time gameplay**: Uses Phoenix LiveView to synchronize game state in real-time between two players
- **Game state management**: Uses GenServer and DynamicSupervisor to manage multiple concurrent games
- **Random island placement**: Automatically places islands randomly when starting a game
- **Turn-based logic**: Turn-based logic between two players managed by a state machine

## How to Play

1. Create a new game or join a game using a `game_id`
2. Wait for the second player to join
3. Islands will be automatically placed on your board
4. Take turns clicking cells on your opponent's board to guess island positions
5. The first player to forest all of their opponent's islands wins

## Installation and Running

To start your Phoenix server:

* Run `mix setup` to install and setup dependencies
* Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Learn more

* Official website: https://www.phoenixframework.org/
* Guides: https://hexdocs.pm/phoenix/overview.html
* Docs: https://hexdocs.pm/phoenix
* Forum: https://elixirforum.com/c/phoenix-forum
* Source: https://github.com/phoenixframework/phoenix
