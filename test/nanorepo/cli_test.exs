defmodule NanoRepo.CLITest do
  use ExUnit.Case, async: true
  alias NanoRepo.CLI

  defmodule Foo do
    def init(opts), do: opts

    def call(conn, _) do
      Plug.Conn.send_resp(conn, 200, "foo")
    end
  end

  test "nanorepo" do
    Logger.configure(level: :warn)
    File.rm_rf!("tmp")
    File.mkdir_p!("tmp")

    File.cd!("tmp", fn ->
      # init

      CLI.main(~w(init acme))

      # server

      {:ok, _} = start_server(port: 4001)

      config = %{
        :hex_core.default_config()
        | repo_name: "acme",
          repo_public_key: File.read!("acme_public_key.pem"),
          repo_url: "http://localhost:4001/acme"
      }

      assert {:ok, {200, _, []}} = :hex_repo.get_names(config)
      assert {:ok, {200, _, []}} = :hex_repo.get_versions(config)

      # build

      File.mkdir_p!("pkg")

      File.cd!("pkg", fn ->
        File.write!("mix.exs", mix_exs(:acme_core, "1.0.0", [{:hex_core, "~> 1.0"}]))
        0 = Mix.shell().cmd("mix hex.build")
      end)

      # publish

      CLI.main(~w(publish acme pkg/acme_core-1.0.0.tar))
      {:ok, {200, _, _}} = :hex_repo.get_tarball(config, "acme_core", "1.0.0")
      {:ok, {200, _, names}} = :hex_repo.get_names(config)
      assert [%{name: "acme_core"}] = names
      {:ok, {200, _, versions}} = :hex_repo.get_versions(config)
      assert [%{name: "acme_core", versions: ["1.0.0"]}] = versions
      {:ok, {200, _, package}} = :hex_repo.get_package(config, "acme_core")
      assert [%{version: "1.0.0"}] = package

      # rebuild

      CLI.main(~w(rebuild acme))
      {:ok, {200, _, names}} = :hex_repo.get_names(config)
      assert [%{name: "acme_core"}] = names
      {:ok, {200, _, versions}} = :hex_repo.get_versions(config)
      assert [%{name: "acme_core", versions: ["1.0.0"]}] = versions
      {:ok, {200, _, package}} = :hex_repo.get_package(config, "acme_core")
      assert [%{version: "1.0.0"}] = package
      {:ok, {200, _, _}} = :hex_repo.get_tarball(config, "acme_core", "1.0.0")

      # new release

      File.cd!("pkg", fn ->
        File.write!("mix.exs", mix_exs(:acme_core, "1.1.0", [{:hex_core, "~> 1.0"}]))
        0 = Mix.shell().cmd("mix hex.build")
      end)

      CLI.main(~w(publish acme pkg/acme_core-1.1.0.tar))
      {:ok, {200, _, names}} = :hex_repo.get_names(config)
      assert [%{name: "acme_core"}] = names
      {:ok, {200, _, versions}} = :hex_repo.get_versions(config)
      assert [%{name: "acme_core", versions: ["1.0.0", "1.1.0"]}] = versions
      {:ok, {200, _, package}} = :hex_repo.get_package(config, "acme_core")
      assert [%{version: "1.0.0"}, %{version: "1.1.0"}] = package
      {:ok, {200, _, _}} = :hex_repo.get_tarball(config, "acme_core", "1.1.0")

      # new package

      File.cd!("pkg", fn ->
        File.write!("mix.exs", mix_exs(:acme_ui, "2.5.0", [{:acme, "~> 1.0"}]))
        0 = Mix.shell().cmd("mix hex.build")
      end)

      CLI.main(~w(publish acme pkg/acme_ui-2.5.0.tar))
      {:ok, {200, _, names}} = :hex_repo.get_names(config)
      assert [%{name: "acme_core"}, %{name: "acme_ui"}] = names
      {:ok, {200, _, versions}} = :hex_repo.get_versions(config)
      assert [%{name: "acme_core", versions: ["1.0.0", "1.1.0"]}, %{name: "acme_ui"}] = versions
      {:ok, {200, _, package}} = :hex_repo.get_package(config, "acme_ui")
      assert [%{version: "2.5.0"}] = package
      {:ok, {200, _, _}} = :hex_repo.get_tarball(config, "acme_ui", "2.5.0")

      # init.mirror

      :ok = Application.stop(:ranch)
      :ok = Application.start(:ranch)
      plug = {Plug.Static, at: "/", from: "public"}
      start_supervised!({Plug.Cowboy, scheme: :http, port: 4002, plug: plug})

      CLI.main(~w(init.mirror mymirror acme http://localhost:4002/acme acme_public_key.pem))

      {:ok, _} = start_server(port: 4003)

      mirror_config = %{
        :hex_core.default_config()
        | repo_name: "acme",
          repo_public_key: File.read!("mymirror_public_key.pem"),
          repo_url: "http://localhost:4003/mymirror"
      }

      {:ok, {200, _, names}} = :hex_repo.get_names(mirror_config)
      assert %{name: "acme_core"} in names
      {:ok, {200, _, tarball}} = :hex_repo.get_tarball(mirror_config, "acme_core", "1.0.0")
      {:ok, %{metadata: %{"name" => "acme_core"}}} = :hex_tarball.unpack(tarball, :memory)
    end)
  end

  defp mix_exs(app, version, deps) do
    """
    defmodule #{Macro.camelize(Atom.to_string(app))}.MixProject do
      use Mix.Project

      def project() do
        [
          app: #{inspect(app)},
          version: #{inspect(version)},
          package: [
            licenses: ["Apache-2.0"],
            description: "Lorem ipsum.",
            links: %{}
          ],
          deps: #{inspect(deps)}
        ]
      end
    end
    """
  end

  defp start_server(opts) do
    self = self()

    {:ok, task_pid} =
      Task.start_link(fn ->
        NanoRepo.start_server(opts)
        send(self, :started)
        Process.sleep(:infinity)
      end)

    assert_receive :started
    {:ok, task_pid}
  end
end
