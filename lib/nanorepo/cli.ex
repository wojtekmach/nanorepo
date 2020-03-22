defmodule NanoRepo.CLI do
  @moduledoc false

  @switches [port: :integer]

  def main(args) do
    {opts, args} = OptionParser.parse!(args, strict: @switches)

    case args do
      ["init", repo_name] ->
        NanoRepo.init(repo_name)

      ["publish", repo_name, tarball_path] ->
        NanoRepo.publish(repo_name, tarball_path)

      ["rebuild", repo_name] ->
        NanoRepo.rebuild(repo_name)

      ["server"] ->
        NanoRepo.start_server(opts)
        Process.sleep(:infinity)

      ["help"] ->
        usage()

      _ ->
        usage()
        System.halt(1)
    end
  end

  defp usage() do
    IO.puts("""
    Usage:

      nanorepo init REPO

        Prepares repository hosting for REPO in the current directory.
        You may initialize multiple different repositories in the same base directory.

      nanorepo publish REPO TARBALL_PATH

        Publishes TARBALL_PATH to REPO.

      nanorepo rebuild REPO

        Rebuilds the given REPO from it's stored tarballs.

      nanorepo server [--port PORT]

        Serves files stored in `public/` of the current directory.

        Options:

          * `--port` - defaults to 4000.
    """)
  end
end
