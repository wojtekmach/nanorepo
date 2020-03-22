defmodule NanoRepo.Utils do
  @moduledoc false

  def mkdir!(path) do
    path = path(path)
    IO.puts([IO.ANSI.green(), "* creating", IO.ANSI.reset(), " ", path])
    File.mkdir_p!(path)
  end

  def write_file!(path, contents) do
    path = path(path)

    if File.exists?(path) do
      IO.puts([IO.ANSI.yellow(), "* updating", IO.ANSI.reset(), " ", path])
    else
      IO.puts([IO.ANSI.green(), "* creating", IO.ANSI.reset(), " ", path])
    end

    File.mkdir_p!(Path.dirname(path))
    File.write!(path, contents)
  end

  def copy_file!(from, to) do
    IO.puts([IO.ANSI.green(), "* copying", IO.ANSI.reset(), " ", from, " to ", to])
    File.cp!(from, to)
  end

  def read_file!(path) do
    path |> path() |> File.read!()
  end

  def path(path) do
    path |> List.wrap() |> List.flatten() |> Path.join()
  end

  def http_get(config, url) do
    headers = %{}
    :hex_http.request(config, :get, url, headers, :undefined)
  end

  def parse_tarball_path(name_version_tar) do
    ".tar" = Path.extname(name_version_tar)
    [name, version] = String.split(Path.basename(name_version_tar, ".tar"), "-")
    {name, version}
  end
end
