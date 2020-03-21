defmodule NanoRepo.Application do
  @moduledoc false

  def start(_type, _args) do
    children = [
      NanoRepo.Mirrors
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: NanoRepo.Supervisor)
  end
end
