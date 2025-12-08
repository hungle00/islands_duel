// Bring in Phoenix channels client library:
import {Socket} from "phoenix"

// Connect to the socket
let socket = new Socket("/socket", {authToken: window.userToken})
socket.connect()

// Get game_id and username from data attributes
function getGameData() {
  const gameSection = document.querySelector("[data-game-id]")
  if (!gameSection) return null

  return {
    gameId: gameSection.getAttribute("data-game-id"),
    username: gameSection.getAttribute("data-username")
  }
}

// Create and join game channel
function initGameChannel() {
  const gameData = getGameData()
  if (!gameData || !gameData.gameId || !gameData.username) {
    console.log("Game data not found, skipping channel join")
    return null
  }

  const channel = socket.channel("game:" + gameData.gameId, {
    game_id: gameData.gameId,
    username: gameData.username
  })

  channel.join()
    .receive("ok", resp => {
      console.log("Joined game channel successfully", resp)
    })
    .receive("error", resp => {
      console.log("Unable to join game channel", resp)
    })

  // Listen for player_added events
  channel.on("player_added", payload => {
    console.log("Player added event:", payload.message)
  })

  return channel
}

// Initialize channel when DOM is ready
if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", () => {
    initGameChannel()
  })
} else {
  initGameChannel()
}

export default socket
