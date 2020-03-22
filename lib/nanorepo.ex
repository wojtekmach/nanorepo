defmodule NanoRepo do
  import NanoRepo.Utils

  def init(repo_name) do
    {private_key, public_key} = NanoRepo.Registry.generate_random_keys()
    write_file!(private_key_path(repo_name), private_key)
    write_file!(public_key_path(repo_name), public_key)

    registry = %NanoRepo.Registry{
      name: repo_name,
      public_key: public_key,
      private_key: private_key
    }

    names = NanoRepo.Registry.build_names(registry, [])
    versions = NanoRepo.Registry.build_versions(registry, [])
    mkdir!(["public", registry.name, "tarballs"])
    mkdir!(["public", registry.name, "packages"])
    write_file!(names_path(registry.name), names)
    write_file!(versions_path(registry.name), versions)
  end

  def start_server(opts) do
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

  def names_path(repo_name), do: ["public", repo_name, "names"]

  def versions_path(repo_name), do: ["public", repo_name, "versions"]

  def package_path(repo_name, name), do: ["public", repo_name, "packages", name]

  def tarballs_path(repo_name), do: ["public", repo_name, "tarballs"]

  def tarball_path(repo_name, name, version),
    do: path([tarballs_path(repo_name), "#{name}-#{version}.tar"])
end
