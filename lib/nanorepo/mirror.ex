defmodule NanoRepo.Mirror do
  @moduledoc false
  defstruct [:name, :url, :registry]
end

defmodule NanoRepo.Mirrors do
  use Agent

  @name __MODULE__

  def start_link([]) do
    Agent.start_link(fn -> %{} end, name: @name)
  end

  def register(options) do
    mirror = struct!(NanoRepo.Mirror, options)
    Agent.update(@name, &Map.put(&1, mirror.name, mirror))
  end

  def fetch(name) do
    Agent.get(@name, &Map.fetch(&1, name))
  end

  def get_tarball(mirror_name, {name, version}) do
    with {:ok, mirror} <- fetch(mirror_name),
         {:ok, {200, _, tarball}} <- :hex_repo.get_tarball(config(mirror), name, version) do
      File.write!(
        Path.join(["public", mirror_name, "tarballs", "#{name}-#{version}.tar"]),
        tarball
      )

      {:ok, tarball}
    else
      _ ->
        :error
    end
  end

  def get_tarball(mirror_name, name_version_tar) do
    get_tarball(mirror_name, NanoRepo.Utils.parse_tarball_path(name_version_tar))
  end

  defp config(mirror) do
    %{
      :hex_core.default_config()
      | repo_name: mirror.registry.name,
        repo_url: mirror.url,
        repo_public_key: mirror.registry.public_key
    }
  end
end
