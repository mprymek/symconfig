defmodule SymConfig.Cli do

  def main([cmd|args]) do
    cond do
      String.starts_with?("provision",cmd) ->
        cmd_provision(args)
      true ->
        usage
    end
  end

  def main(_) do
    usage
  end

  defp cmd_provision([script]) do
    SymConfig.Runner.run(script,:provision)
  end
  defp cmd_provision(_), do: usage

  defp usage do
    IO.puts """
    Usage:

        symconfig p[rovision] script.exs
    """
  end
end
