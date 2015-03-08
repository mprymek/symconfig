defmodule PkgDeps do
  @type t :: Mtree.File | Mtree.Dir | Mtree.Link

  @spec from_string(binary) :: [t]
  def from_string(deps_str) do
    {:ok,pseudo_file} = StringIO.open(deps_str)
    process_file(pseudo_file, [])
  end

  @spec from_file(binary) :: [t]
  def from_file(filename) do
    input_file = File.open!(filename, [:read, :utf8])
    process_file(input_file, [])
  end

  @spec process_file(:file.io_device, [t]) :: [t]
  defp process_file(input_file, items) do
    line = IO.read(input_file, :line)
    if (line != :eof) do
      process_file(input_file, [process_line(line) | items])
    else
      items
    end
  end

  @spec process_line(binary) :: t
  defp process_line(line) do
    case Regex.named_captures ~r/^(?<n1>[^ ]+)-(?<v1>[^ ]+) (?<n2>[^ ]+)-(?<v2>[^ ]+)\n$/, line do
      %{"n1"=>n1,"v1"=>v1,"n2"=>n2,"v2"=>v2} -> {n1,v1,n2,v2}
      nil -> raise "Invalid line in pkgdeps file: #{inspect line}"
    end
  end

end
