defmodule SymConfig.RestartProvision do
  defexception [:message,:sc]
end

defmodule SymConfig.State do
  defstruct host: nil, port: 22, user: nil, ssh_options: nil, con: nil, edb: nil, vars_fun: nil
end

defmodule SymConfig do
  require Logger
  require Exlog
  alias SymConfig.State
  alias SymConfig.Inference
  alias SymConfig.RestartProvision

  def init(vars,host,user\\"root",port\\22,options\\[]) do
    vars_fun = case vars do
      vars when is_map(vars) ->
        fn varset -> vars[varset] end
      vars when is_function(vars) ->
        vars
    end
    pl_file = Path.join(SymConfig.Cfg.pl_dir,"symconfig.pl")
    Logger.debug "Loading inference core from #{pl_file}"
    edb = Exlog.new
          |> Exlog.consult!(pl_file)
    %State{host: host, user: user, port: port, ssh_options: options, edb: edb, vars_fun: vars_fun}
    |> connect
  end

  def connect(s=%State{}) do
    con = Ssh.connect s.host, s.user, s.port, s.ssh_options
    %State{s|con: con}
  end

  def cmd(s=%State{},cmd) do
    res = Ssh.cmd s.con, cmd
    {s,res}
  end

  def get_file!(s=%State{}, file) do
    data = Ssh.get_file! s.con, file
    {s,data}
  end

  def put_file!(s=%State{}, data, file) do
    :ok = Ssh.put_file! s.con, data, file
    s
  end

  def close(s=%State{}) do
    Ssh.close s.con
    %State{s|con: nil}
  end

  def assert!(s=%State{edb: edb},facts) when is_list(facts) do
    edb = facts |> Enum.reduce(edb, fn
      fact, edb ->
        {edb,{true,_}} = edb |> Exlog.e_prove({:assert,fact})
        edb
    end)
    %State{s|edb: edb}
  end
  def assert!(s=%State{},fact), do: assert!(s,[fact])

  defmacro query(s,q) do
    quote do
      {_edb,result} = unquote(s).edb |> Exlog.prove_all(unquote(q))
      result
    end
  end

  # @TODO: DB listing
  def listing(s=%State{edb: edb}) do
    db = :erlog.get_db(edb)
       |> :dict.to_list
       |> Enum.sort
       |> Enum.map(fn
           {_,:built_in} -> []
           {{ftor,arity},clauses} ->
             #IO.puts "#{ftor}/#{arity}"
             case clauses do
               {:clauses,_n,clauses} ->
                 s_clauses = clauses |> Enum.map(fn
                   clause ->
                     insp_clause(clause)
                 end)
                 [s_clauses,".\n"]
               {:code,code_def} ->
                 [insp_clause(code_def),".\n"]
             end
          end)
  end
  defp insp_clause({mod,fun}) do
    "\n    #{mod}.#{fun}"
  end
  defp insp_clause({_,head,{[],false}}) do
    ["\n",insp_term(head),".\n"]
  end
  defp insp_clause({_,head,{body,_}}) do
    s_body = body |> Enum.map(fn
      x -> insp_term(x)
    end) |> Enum.join(",")
    ["\n",insp_term(head)," :-\n    ",s_body]
  end
  defp insp_term({var}) when is_atom(var) do
    s_var = var |> Atom.to_string
    <<x::size(8),_::binary>> = s_var
    if (x>=?A and x<=?Z) or (x>=?a and x<=?z) or x==?_ do
      s_var
    else
      inspect(var)
    end
  end
  defp insp_term(x) when is_tuple(x) do
    [ftor|args] = x |> Tuple.to_list
    args2 = args |> Enum.map(fn x -> insp_term(x) end)
      |> Enum.join(",")
    s_ftor = case ftor do
      x when is_atom(x) -> Atom.to_string x
      x -> inspect(x)
    end
    [s_ftor,"(",args2,")"]
  end
  defp insp_term(t) do
    inspect(t)
  end

  def db_cache_or_fn(s=%State{},db_name,fun) do
    edb = cache_or_fn(db_name<>".edb",fn _ -> fun.(s) end)
    %State{s|edb: edb}
  end

  def cache_or_fn(fpath,fun) do
    basename = Path.basename fpath
    cache_file = Path.join [SymConfig.Cfg.cache_dir,basename<>".erlbin"]
    if false and File.exists?(cache_file)do
      Logger.info "Loading data from cache: #{cache_file}"
      File.read!(cache_file) |> :erlang.binary_to_term
    else
      data = fun.(fpath)
      f = File.open!(cache_file,[:write,:binary])
      f |> IO.binwrite(data |> :erlang.term_to_binary)
      :ok = f |> File.close
      Logger.info "Datafile #{fpath} cached as #{cache_file}"
      data
    end
  end

  def load_mtree(s=%State{edb: edb},o,mtree_file) do
    mtree = cache_or_fn(mtree_file,fn f -> Mtree.from_file f end)
    edb = mtree |> Enum.reduce(edb,fn
      %Mtree.File{path: path, flags: flags, gid: gid, uid: uid, mode: mode, sha256: sha, size: size}, edb ->
        edb |> Exlog.assert!( file_meta(o,path,:file,uid,gid,mode,flags,size,HexStr.encode(sha)) )
      %Mtree.Link{path: path, flags: flags, gid: gid, uid: uid, mode: mode, target: target}, edb ->
        edb |> Exlog.assert!( file_meta(o,path,:link,uid,gid,mode,flags,nil,target) )
        edb
      %Mtree.Dir{path: path, flags: flags, gid: gid, uid: uid, mode: mode}, edb ->
        edb |> Exlog.assert!( file_meta(o,path,:dir,uid,gid,mode,flags,nil,nil) )
      any, _edb ->
        raise "Unexpected mtree item: #{inspect any}"
    end)
    %State{s|edb: edb}
  end

  def load_pl(s=%State{edb: edb},pl_file) do
    edb = edb |> Exlog.consult!(pl_file)
    %State{s|edb: edb}
  end

  def load_pkgdeps(s=%State{edb: edb},deps_file) do
    deps = cache_or_fn(deps_file,fn f -> PkgDeps.from_file f end)
    edb = deps |> Enum.reduce(edb,fn
      {n1,v1,n2,v2}, edb ->
        #Logger.info "pkg_depends(pkg(#{inspect n1},#{inspect v1}),pkg(#{inspect n2},#{inspect v2}))"
        edb |> Exlog.assert!( pkg_depends(pkg(n1,v1),pkg(n2,v2)) )
      any, _edb ->
        raise "Unexpected mtree item: #{inspect any}"
    end)
    %State{s|edb: edb}
  end

  defp mtree2({edb,{true,[A: a, B: b=:dir, C: c, D: d, E: e, F: f, G: nil, H: nil]}}) do
    a = case a do
      "/" -> ""
      a -> a
    end
    flags_s = f |> Enum.map(&Atom.to_string/1) |> Enum.join(",")
    line = ".#{a} type=#{b} uid=#{c} gid=#{d} mode=0#{e} flags=#{flags_s}\n"
    {[line],edb}
  end
  defp mtree2({edb,{true,[A: a, B: :file, C: c, D: d, E: e, F: f, G: g, H: h]}}) do
    flags_s = f |> Enum.map(&Atom.to_string/1) |> Enum.join(",")
    line = ".#{a} type=file uid=#{c} gid=#{d} mode=0#{e} size=#{g} sha256digest=#{h} flags=#{flags_s}\n"
    {[line],edb}
  end
  defp mtree2({edb,{false,[]}}) do {:halt,nil} end

  # NOTE: we must return list instead of stream because we have duplicated, unsorted items (should be removed in the future)
  defp mtree1(s=%State{edb: edb}) do
    Stream.resource(
      # start_fun
      fn -> {:first,edb} end,
      # next_fun
      fn
        {:first,edb} ->
          edb |> Exlog.prove( justified(file_meta(A,B,C,D,E,F,G,H)) )
              |> mtree2
        edb ->
          edb |> Exlog.next_solution
              |> mtree2
      end,
      # after_fun
      fn _ -> :ok end
    )
  end

  def mtree(s=%State{}) do
    s |> mtree1 |> Enum.uniq |> Enum.sort
  end

  def mtree_test(s=%State{edb: edb}) do
    mtree_str = s |> mtree |> IO.iodata_to_binary
    s |> put_file!(mtree_str,"/tmp/sc.mtree")
    {s,{res,out}} = s |> cmd("mtree -ef /tmp/sc.mtree -p / && rm /tmp/sc.mtree")
    unless res==0 do
      Logger.error "Mtree test failed with: #{out}"
    end
    {s,res==0}
  end

  def required_files(s=%State{}) do
    s |> query( required(file_meta(A,B,C,D,E,F,G,H)) ) |> Enum.uniq
      |> Enum.map(fn
           [A: a, B: b, C: c, D: d, E: e, F: f, G: g, H: h] ->
             {:file_meta,a,b,c,d,e,f,g,h}
         end)
  end

  def required(s=%State{}) do
    s |> query( required(X) ) |> Enum.uniq
      |> Enum.map(fn
           [X: x] -> x
         end)
  end

  def justified(s=%State{}) do
    s |> query( justified(X) ) |> Enum.uniq
      |> Enum.map(fn
           [X: x] -> x
         end)
  end

  def in_state(s=%State{},state) do
    case s.edb |> Inference.to_achieve(state) do
      [] -> true
      _ -> false
    end
  end

  def vars(_,nil), do: []
  def vars(s=%State{vars_fun: f},id), do: f.(id)

  def provision!(s=%State{}) do
    way = s.edb
          |> Inference.all_to_achieve(:acceptable_state)
    Logger.info "Way to acceptable state: #{inspect way}"
    %State{s|edb: s.edb}
  end

  def provision!(s1=%State{}, actor, state\\:acceptable_state) do
    case s1.edb |> Inference.to_achieve(state) do
      [] ->
        #Logger.debug "Acceptable state reached."
        actor.(s1,{:reached,state})
      steps ->
        #Logger.debug "Next steps to acceptable state: #{inspect steps}"
        try do
          s2 = steps |> Enum.reduce(s1,fn step,s -> actor.(s,step) end)
          provision! s2, actor, state
        rescue
          e in RestartProvision ->
            Logger.info "Restarting provisioning because: #{e.message}"
            provision! e.sc, actor, state
        end
    end
  end

end
