defmodule NanoRepo.Utils do
  @moduledoc false

  def generate_keys() do
    {:ok, private_key} = generate_rsa_key(2048, 65537)
    public_key = extract_public_key(private_key)
    {pem_encode(:RSAPrivateKey, private_key), pem_encode(:RSAPublicKey, public_key)}
  end

  require Record

  Record.defrecordp(
    :rsa_private_key,
    :RSAPrivateKey,
    Record.extract(:RSAPrivateKey, from_lib: "public_key/include/OTP-PUB-KEY.hrl")
  )

  Record.defrecordp(
    :rsa_public_key,
    :RSAPublicKey,
    Record.extract(:RSAPublicKey, from_lib: "public_key/include/OTP-PUB-KEY.hrl")
  )

  defp pem_encode(type, key) do
    :public_key.pem_encode([:public_key.pem_entry_encode(type, key)])
  end

  defp generate_rsa_key(keysize, e) do
    private_key = :public_key.generate_key({:rsa, keysize, e})
    {:ok, private_key}
  rescue
    FunctionClauseError ->
      {:error, :not_supported}
  end

  defp extract_public_key(rsa_private_key(modulus: m, publicExponent: e)) do
    rsa_public_key(modulus: m, publicExponent: e)
  end

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
