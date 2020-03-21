defmodule NanoRepo.CLI do
  @moduledoc false

  @switches [port: :integer, mirror: :keep]

  def main(args) do
    {opts, args} = OptionParser.parse!(args, strict: @switches)

    case args do
      ["init", repo_name] ->
        NanoRepo.init(repo_name)

      ["init.mirror", repo_name, "hexpm"] ->
        NanoRepo.init_mirror(repo_name, "hexpm")

      ["init.mirror", repo_name, mirror_repo_name, mirror_url, mirror_public_key_path] ->
        NanoRepo.init_mirror(repo_name, {mirror_repo_name, mirror_url, mirror_public_key_path})

      ["publish", repo_name, tarball_path] ->
        NanoRepo.publish(repo_name, tarball_path)

      ["rebuild", repo_name] ->
        NanoRepo.rebuild(repo_name)

      ["serve"] ->
        NanoRepo.start_endpoint(opts)
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

      nanorepo init.mirror REPO hexpm

        Prepares mirror for hex.pm as REPO in the current directory.

      nanorepo init.mirror REPO MIRROR_REPO_NAME MIRROR_URL MIRROR_PUBLIC_KEY_PATH

        Prepares mirror for MIRROR_REPO_NAME as REPO in the current directory.

        A mirror is a read-through cache for the given MIRROR_URL. `nanorepo init.mirror`
        just fetches and stores `/names` and `/versions` registry index files,
        all the other files would be read on-demand. To enable the read-through cache,
        pass `--mirror` to `nanorepo serve`.

      nanorepo publish REPO TARBALL_PATH

        Publishes TARBALL_PATH to REPO.

      nanorepo rebuild REPO

        Rebuilds the given REPO from it's stored tarballs.

      nanorepo serve [--port PORT --mirror MIRROR]

        Serves files stored in `public/` for repositories initialized in the current
        directory.

        Options:

          * `--port` - defaults to 4000.
          * `--mirror` - the name of the mirror that was initialized with `init.mirror`.
            This option may be given multiple times to support multiple mirrors.
    """)
  end
end
