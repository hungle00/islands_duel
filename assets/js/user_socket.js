// NOTE: The contents of this file will only be executed if
// you uncomment its entry in "assets/js/app.js".

// Bring in Phoenix channels client library:
import {Socket} from "phoenix"

// And connect to the path in "lib/islands_duel_web/endpoint.ex". We pass the
// token for authentication.
//
// Read the [`Using Token Authentication`](https://hexdocs.pm/phoenix/channels.html#using-token-authentication)
// section to see how the token should be used.
let socket = new Socket("/socket", {authToken: window.userToken})
socket.connect()

// Now that you are connected, you can join channels with a topic.
// Let's assume you have a channel with a topic named `room` and the
// subtopic is its id - in this case 42:

function new_channel(player, screen_name) {
  return socket.channel("game:" + player, {screen_name: screen_name});
}

function join(channel) {
  channel.join()
    .receive("ok", resp => { console.log("Joined successfully", resp) })
    .receive("error", resp => { console.log("Unable to join", resp) })
}

let game_channel = new_channel("moon", "diva")
join(game_channel)

function new_game(channel){
  channel.push("new_game")
    .receive("ok", response => {
      console.log("New Game!", response)
    })
    .receive("error", response => {
      console.log("Unable to start a new game.", response)
    })
}

function add_player(channel, player) {
  channel.push("add_player", player)
    .receive("error", response => {
      console.log("Unable to add new player: " + player, response)
  })
}

new_game(game_channel)

game_channel.on("player_added", response => {
  console.log("Player Added", response)
})

export default socket
