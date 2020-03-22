defmodule NanoRepo.Endpoint do
  @moduledoc false

  use Plug.Router
  plug Plug.Logger
  plug Plug.Static, at: "/", from: "public"
  plug :match
  plug :dispatch

  match _ do
    send_resp(conn, 404, "not found")
  end
end
