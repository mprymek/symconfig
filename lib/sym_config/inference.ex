defmodule SymConfig.Inference do
  require Logger
  use Exlog

  def to_achieve(e,state) do
    {_e, res} = e |> prove_all( to_achieve(state,X) )
    res |> Enum.map(fn
      [X: tgt] -> tgt
    end) |> Enum.uniq
  end

  def all_to_achieve(e,state), do:
    all_to_achieve(e,state,[])

  def all_to_achieve(e,state,actions) do
    case e |> prove_all( to_achieve(state,X) ) do
      {_e,[]} ->
        Enum.reverse actions
      {e,res} ->
        tgts = res |> Enum.map(fn
          [X: tgt] -> tgt
        end) |> Enum.uniq
        e = tgts |> Enum.reduce(e,fn
          {:verify,item}, e ->
            {e, {true,[]}} = e |> e_prove( {:assert,{:detected,item}} )
            e
          x, _e ->
            raise "Can't simulate step: #{inspect x}"
        end)
        #Logger.info "tgts = #{inspect tgts}"
        all_to_achieve e, state, [tgts|actions]
    end
  end

  def required(e) do
    {_e, res} = e |> prove_all( required(X) )
    res |> Enum.map(fn
      [X: x] -> x
    end) |> Enum.uniq
  end

  def justified(e) do
    {_e, res} = e |> prove_all( justified(X) )
    res |> Enum.map(fn
      [X: x] -> x
    end) |> Enum.uniq
  end
end
