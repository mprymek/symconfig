defmodule Mtree.File do
  defstruct path: nil, flags: nil, gid: nil, uid: nil, mode: nil, sha256: nil, size: nil
end

defmodule Mtree.Dir do
  defstruct path: nil, flags: nil, gid: nil, uid: nil, mode: nil
end

defmodule Mtree.Link do
  defstruct path: nil, flags: nil, gid: nil, uid: nil, mode: nil, target: nil
end

defmodule Mtree do
  @type t :: Mtree.File | Mtree.Dir | Mtree.Link

  @spec from_string(binary) :: [t]
  def from_string(mtree_str) do
    {:ok,pseudo_file} = StringIO.open(mtree_str)
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
    # @TODO: spaces not allowed in filename!
    ["."<>path,attrs] = case Regex.run ~r/^(?<file>[^ ]+)(.*)\n$/, line, capture: :all_but_first do
      nil -> raise "Cannot parse line #{inspect line}"
      x=[_path,_attrs] -> x
    end
    attrs = process_attrs(attrs)
    flags = case attrs["flags"] do
      nil -> nil
      flags_str ->
        flags_str |> String.split(",") |> Enum.map(&String.to_atom/1)
    end
    uid = case attrs["uid"] do
      nil -> nil
      x -> x |>String.to_integer
    end
    gid = case attrs["gid"] do
      nil -> nil
      x -> x |>String.to_integer
    end
    mode = attrs["mode"] |> String.to_integer
    #mode = case attrs["mode"] do
    #  nil -> nil
    #  <<"0", a::size(8), b::size(8), c::size(8)>> ->
    #    [a,b,c] |> Enum.reduce(0,fn
    #      digit, acc when digit<?8 and digit>=?0 ->
    #        (acc*8) + (digit-?0)
    #    end)
    #  <<"0", a::size(8), b::size(8), c::size(8), d::size(8)>> ->
    #    [a,b,c,d] |> Enum.reduce(0,fn
    #      digit, acc when digit<?8 and digit>=?0 ->
    #        (acc*8) + (digit-?0)
    #    end)
    #end
    sha256 = case attrs["sha256digest"] do
      nil -> nil
      sha -> HexStr.decode sha
    end
    size = case attrs["size"] do
      nil -> nil
      x -> x |>String.to_integer
    end
    case attrs["type"] do
      "file" -> %Mtree.File{path: path, flags: flags, gid: gid, uid: uid, mode: mode, sha256: sha256, size: size}
      "dir" -> %Mtree.Dir{path: path, flags: flags, gid: gid, uid: uid, mode: mode}
      "link" -> %Mtree.Link{path: path, flags: flags, gid: gid, uid: uid, mode: mode, target: attrs["link"]}
      any -> raise "Unsupported mtree item type #{inspect any} in #{inspect attrs}"
    end
  end

  @spec process_attrs(binary) :: %{}
  defp process_attrs(attrs) do
    Regex.scan(~r/ ([^=]+)=([^ ]+)/, attrs, capture: :all_but_first)
    |> Enum.reduce(%{},fn [key,val], map -> map |> Map.put(key,val) end)
  end

end
