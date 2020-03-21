defmodule NanoRepo.Registry do
  defstruct [:name, :public_key, :private_key]

  def build_names(registry, packages) do
    sorted = Enum.sort(packages)

    %{repository: registry.name, packages: sorted}
    |> :hex_registry.encode_names()
    |> sign_and_gzip(registry.private_key)
  end

  def unpack_names(registry, gzipped) do
    with {:ok, payload} <- gunzip_signed(gzipped, registry.public_key) do
      # TODO: verify!
      :hex_registry.decode_names(payload, :no_verify)
    end
  end

  def build_versions(registry, packages) do
    %{repository: registry.name, packages: packages}
    |> :hex_registry.encode_versions()
    |> sign_and_gzip(registry.private_key)
  end

  def unpack_versions(registry, gzipped) do
    with {:ok, payload} <- gunzip_signed(gzipped, registry.public_key) do
      :hex_registry.decode_versions(payload, registry.name)
    end
  end

  def build_package(registry, name, releases) do
    sorted = Enum.sort(releases, &(Version.compare(&1.version, &2.version) == :lt))

    %{repository: registry.name, name: name, releases: sorted}
    |> :hex_registry.encode_package()
    |> sign_and_gzip(registry.private_key)
  end

  def unpack_package(registry, gzipped, name) do
    with {:ok, payload} <- gunzip_signed(gzipped, registry.public_key) do
      :hex_registry.decode_package(payload, registry.name, name)
    end
  end

  defp sign_and_gzip(protobuf, private_key) do
    protobuf
    |> :hex_registry.sign_protobuf(private_key)
    |> :zlib.gzip()
  end

  defp gunzip_signed(gzipped, public_key) do
    gzipped
    |> :zlib.gunzip()
    |> :hex_registry.decode_and_verify_signed(public_key)
  end
end
