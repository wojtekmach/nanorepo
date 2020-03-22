defmodule NanoRepo do
  import NanoRepo.Utils

  def init(repo_name) do
    init_repo(repo_name)
  end

  def init_mirror(repo_name, "hexpm") do
    config = :hex_core.default_config()
    init_mirror(repo_name, "hexpm", config.repo_url, config.repo_public_key)
  end

  def init_mirror(repo_name, {mirror_repo_name, mirror_url, mirror_public_key_path}) do
    mirror_public_key = read_file!(mirror_public_key_path)
    init_mirror(repo_name, mirror_repo_name, mirror_url, mirror_public_key)
  end

  def start_server(opts) do
    for path <- mirror_config_paths() do
      repo_name = Path.basename(path, ".mirror.exs")
      config = Config.Reader.read!(path) |> Keyword.fetch!(:mirror)
      mirror_name = Keyword.fetch!(config, :name)
      mirror_url = Keyword.fetch!(config, :url)
      public_key = public_key_path(repo_name) |> File.read!()
      registry = %NanoRepo.Registry{name: mirror_name, public_key: public_key}
      NanoRepo.Mirrors.register(name: repo_name, url: mirror_url, registry: registry)
    end

    port = Keyword.get(opts, :port, 4000)
    IO.puts([IO.ANSI.blue(), "* serving", " ./public on port #{port}", IO.ANSI.reset()])
    plug = NanoRepo.Endpoint
    endpoint = Plug.Cowboy.child_spec(scheme: :http, plug: plug, options: [port: port])
    Supervisor.start_link([endpoint], strategy: :one_for_one)
  end

  def publish(repo_name, tarball_path) do
    {name, version} = parse_tarball_path(tarball_path)
    copy_file!(tarball_path, tarball_path(repo_name, name, version))
    # TODO: do partial build instead of full rebuild
    rebuild(repo_name)
  end

  def rebuild(repo_name) do
    public_key = read_file!("#{repo_name}_public_key.pem")
    private_key = read_file!("#{repo_name}_private_key.pem")

    registry = %NanoRepo.Registry{
      name: repo_name,
      private_key: private_key,
      public_key: public_key
    }

    releases =
      for path <- Path.wildcard(Path.join(tarballs_path(repo_name) ++ ["*.tar"])) do
        [name, version] = String.split(Path.basename(path, ".tar"), "-")
        {name, version}
      end

    packages = Enum.group_by(releases, &elem(&1, 0), &elem(&1, 1))

    # /names
    names = for name <- Map.keys(packages), do: %{name: name}
    data = NanoRepo.Registry.build_names(registry, names)
    write_file!(names_path(repo_name), data)

    # /versions
    versions =
      for {name, versions} <- packages do
        %{name: name, versions: versions, retired: []}
      end

    data = NanoRepo.Registry.build_versions(registry, versions)
    write_file!(versions_path(repo_name), data)

    # /packages/:name

    for {name, versions} <- packages do
      releases =
        for version <- versions do
          tarball = read_file!(tarball_path(repo_name, name, version))
          {:ok, result} = :hex_tarball.unpack(tarball, :memory)

          dependencies =
            for {name, req} <- result.metadata["requirements"] do
              %{
                app: req["app"],
                optional: req["optional"],
                repository: req["repository"],
                requirement: req["requirement"],
                package: name
              }
              |> Enum.filter(&elem(&1, 1))
              |> Map.new()
            end

          %{
            version: version,
            inner_checksum: result.inner_checksum,
            outer_checksum: result.outer_checksum,
            dependencies: dependencies
          }
        end

      data = NanoRepo.Registry.build_package(registry, name, releases)
      write_file!(package_path(repo_name, name), data)
    end
  end

  def private_key_path(repo_name), do: repo_name <> "_private_key.pem"

  def public_key_path(repo_name), do: repo_name <> "_public_key.pem"

  def mirror_config_paths(), do: Path.wildcard("*.mirror.exs")

  def mirror_config_path(repo_name), do: repo_name <> ".mirror.exs"

  def names_path(repo_name), do: ["public", repo_name, "names"]

  def versions_path(repo_name), do: ["public", repo_name, "versions"]

  def package_path(repo_name, name), do: ["public", repo_name, "packages", name]

  def tarballs_path(repo_name), do: ["public", repo_name, "tarballs"]

  def tarball_path(repo_name, name, version),
    do: path([tarballs_path(repo_name), "#{name}-#{version}.tar"])

  defp init_mirror(repo_name, mirror_name, mirror_url, mirror_public_key) do
    write_file!(public_key_path(repo_name), mirror_public_key)
    write_file!(mirror_config_path(repo_name), build_mirror_config(mirror_name, mirror_url))

    registry = %NanoRepo.Registry{
      name: repo_name,
      public_key: mirror_public_key
    }

    mirror_registry = %NanoRepo.Registry{
      name: mirror_name,
      public_key: mirror_public_key
    }

    config = %{
      :hex_core.default_config()
      | repo_name: mirror_name,
        repo_url: mirror_url,
        repo_public_key: mirror_public_key
    }

    {:ok, {200, _, names}} = http_get(config, mirror_url <> "/names")
    {:ok, _} = NanoRepo.Registry.unpack_names(mirror_registry, names)

    {:ok, {200, _, versions}} = http_get(config, mirror_url <> "/versions")
    {:ok, _} = NanoRepo.Registry.unpack_names(mirror_registry, versions)

    init_repo(registry, names, versions)
  end

  defp init_repo(repo_name) do
    {private_key, public_key} = generate_keys()
    write_file!(private_key_path(repo_name), private_key)
    write_file!(public_key_path(repo_name), public_key)

    registry = %NanoRepo.Registry{
      name: repo_name,
      public_key: public_key,
      private_key: private_key
    }

    names = NanoRepo.Registry.build_names(registry, [])
    versions = NanoRepo.Registry.build_versions(registry, [])
    init_repo(registry, names, versions)
  end

  defp init_repo(registry, names, versions) do
    mkdir!(["public", registry.name, "tarballs"])
    mkdir!(["public", registry.name, "packages"])
    write_file!(names_path(registry.name), names)
    write_file!(versions_path(registry.name), versions)
  end

  defp build_mirror_config(name, url) do
    """
    import Config

    config :mirror,
      name: #{inspect(name)},
      url: #{inspect(url)}
    """
  end
end
