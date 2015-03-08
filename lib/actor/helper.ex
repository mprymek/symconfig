defmodule Actor.Helper do
  alias SymConfig, as: SC

  defmacro __using__([]) do
    quote do
      import Actor.Helper
    end
  end

  defmacro verify_fun(pattern,msg,cmd) do
    quote do
      defp verify(sc,unquote(pattern)) do
        Logger.info unquote(msg)
        case sc |> SC.cmd(unquote(cmd)) do
          {sc,{0,_out}} -> {sc,true}
          {sc,{_,out}} ->
            Logger.error "OUT: #{out}"
            {sc,false}
        end
      end
    end
  end

  defmacro force_fun(pattern,msg,cmd) do
    quote do
      defp force(sc,unquote(pattern)) do
        Logger.info unquote(msg)
        case sc |> SC.cmd(unquote(cmd)) do
          {sc,{0,out}} ->
            out |> String.split("\n")
                |> Enum.each(fn line -> Logger.info "#{IO.ANSI.cyan}    #{line}#{IO.ANSI.normal}" end)
            {sc,true}
          {sc,{_,out}} ->
            Logger.error "OUT: #{inspect out}"
            {sc,false}
        end
      end
    end
  end

end

