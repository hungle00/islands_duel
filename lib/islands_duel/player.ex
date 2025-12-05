defmodule IslandsDuel.Player do

  @enforce_keys [:id, :name]
  defstruct [:id, :name]

  @spec new(any()) :: %IslandsDuel.Player{id: binary(), name: any()}
  def new(name) do
    id = :crypto.strong_rand_bytes(12) |> Base.url_encode64(padding: false)
    %IslandsDuel.Player{id: id, name: name}
  end
end
