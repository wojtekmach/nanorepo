defmodule NanoRepo.Endpoint do
  @moduledoc false

  use Plug.Router

  plug Plug.Logger
  plug Plug.Static, at: "/", from: "public"
  plug :match
  plug :dispatch

  get "/:mirror_name/tarballs/:path" do
    {name, version} = NanoRepo.Utils.parse_tarball_path(path)

    case NanoRepo.Mirrors.get_tarball(mirror_name, name, version) do
      {:ok, tarball} -> send_resp(conn, 200, tarball)
      :error -> send_resp(conn, 404, "not found")
    end
  end

  match _ do
    send_resp(conn, 404, "not found")
  end
end
