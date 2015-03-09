defmodule Actor.FreeBSD do
  use Actor.Helper
  require Logger
  alias SymConfig, as: SC
  require Exlog
  require SC
  alias SC.Cfg

  @name __MODULE__

  def act(sc,action) do
    #Logger.debug "#{@name}: action: #{inspect action}"
    #act1(sc,action)
    #detected = sc |> SC.query( detected(X) )
    #Logger.debug "#{@name}: detected: #{inspect detected}"
    {time,sc} = :timer.tc(fn -> act1 sc, action end)
    Logger.debug "#{@name}: exec time: #{time/1000000}s"
    sc
  end

  defp act1(sc,{:fill_cache,{:patch_cache,src_file,src_sha,patch_id,last_ver,varset}}) do
    # download source file if not cached
    src_fpath = Path.join [Cfg.orig_dir, src_sha]
    unless File.exists? src_fpath do
      Logger.info "Downloading source file #{src_file} to #{src_fpath}"
      {sc,src_content} = get_file sc, src_file
      :ok = write_secure src_fpath, src_content
      src_sha2 = sha256 src_fpath
      if src_sha2 != src_sha do
        File.rm! src_fpath
        raise "Downloaded file #{src_file} has sha256=#{src_sha2} but #{src_sha} expected."
      end
      Logger.info "Source file downloaded into #{src_fpath}"
    end

    last_patch = "#{patch_id}-#{last_ver}"
    patch_fpath = Path.join [Cfg.patches_dir,last_patch]

    {templ_sha,templ_fpath} = tmp2cache(fn tmp_fpath ->
      case System.cmd "patch", ["-i",patch_fpath,"-o",tmp_fpath,src_fpath] do
        {_out,0} -> :ok
        {out,_res} ->
          Logger.error "Patch #{last_patch} doesn't apply cleanly"
          out |> String.split("\n")
              |> Enum.each(fn line -> Logger.error "    #{line}" end)
          dead_end "Patch #{patch_id} doesn't apply cleanly. Please make a new version for source file #{src_fpath}"
      end
    end)
    Logger.debug "New template file #{templ_fpath}"

    bindings = sc |> SC.vars(varset)
    bindings_hash = :erlang.phash2 bindings
    dst_content = EEx.eval_file templ_fpath, bindings

    {dst_sha,dst_fpath} = tmp2cache(fn tmp_fpath ->
      write_secure tmp_fpath, dst_content
    end)
    dst_size = File.stat!(dst_fpath).size

    cache_records = [
      {:patch_cache,src_sha,patch_id,templ_sha},
      {:eex_cache,templ_sha,bindings_hash,dst_size,dst_sha},
    ]

    sc = sc |> SC.assert!(cache_records)
    raise SymConfig.RestartProvision, message: "New cache records: #{inspect cache_records,[pretty: true]}", sc: sc
  end

  defp act1(sc,{:verify,x}) do
    case verify(sc,x) do
      {sc,true} -> sc |> SC.assert!([{:detected,x}])
      {sc,false} ->
        sc = case force(sc,x) do
          {sc, true} -> sc
          _ -> dead_end "forcing fact #{inspect x} failed"
        end
        case verify(sc,x) do
          {sc,true} -> sc |> SC.assert!([{:detected,x}])
          _ -> dead_end "verifying forced fact #{inspect x} failed"
        end
    end
  end

  defp act1(sc,{:reached,state}) do
    Logger.info "#{@name}: reached state #{inspect state}"
    sc
  end
  defp act1(_sc,action) do
    dead_end "unknown action #{inspect action}"
  end

  defp write_secure(fpath,content) do
    f = File.open! fpath, [:write,:binary]
    File.chmod! fpath, 0o400
    :ok = IO.binwrite f, content
    :ok = File.close f
    :ok
  end

  defp tmp2cache(write_fun) do
    salt = :erlang.now |> :erlang.phash2
    tmp_fpath = Path.join([Cfg.cache_dir,"tmp-#{salt}"])
    false = File.exists? tmp_fpath
    :ok = write_fun.(tmp_fpath)
    dst_sha = sha256 tmp_fpath
    dst_fpath = Path.join([Cfg.cache_dir,dst_sha])
    :ok = :file.rename tmp_fpath, dst_fpath
    {dst_sha,dst_fpath}
  end

  def get_file(sc,file) do
    try do
      {sc,content} = sc |> SC.get_file!(file)
    rescue
      e ->
        dead_end "cannot download file #{inspect file}. Error: #{inspect e}"
    end
  end

  defp verify(sc,{:installed,{:pkg,pkg_name,pkg_ver}}) do
    Logger.info "#{@name}: verifying pkg #{pkg_name}-#{pkg_ver} is installed"
    case sc |> SC.cmd(~s(pkg info -q "#{pkg_name}-#{pkg_ver}")) do
      {sc,{0,""}} -> {sc,true}
      {sc,{_,out}} ->
        Logger.error "    #{out}"
        {sc,false}
    end
  end

  # @TODO: verify meta
  defp verify(sc,{:file_meta, path, _type, _uid, _gid, _mode, _flags, _size, sha256}) do
    Logger.info "#{@name}: verifying sha256(#{path})==#{sha256}"
    case sc |> SC.cmd(~s(sha256 -qc"#{sha256}" "#{path}")) do
      {sc,{0,_out}} -> {sc,true}
      {sc,{_,out}} ->
        Logger.error "    #{out}"
        {sc,false}
    end
  end

  defp verify(sc,{:installed, {:os, :freebsd, version}}) do
    Logger.info "#{@name}: verifying freebsd version is #{version}"
    case sc |> SC.cmd("echo -n `freebsd-version`-`uname -m`") do
      {sc,{0,^version}} -> {sc,true}
      {sc,{_,out}} ->
        Logger.error "    #{out}"
        {sc,false}
    end
  end

  #verify_fun {:sha256,path,sha}, "#{@name}: verifying sha256(#{path})==#{sha}", ~s(sha256 -qc"#{sha}" "#{path}")
  verify_fun {:running, {:svc,svc}}, "#{@name}: verifying service #{svc} is running.", ~s(service "#{svc}" onestatus)

  # @TODO
  #defp verify(sc,x={:installed,{:os,_,_}}) do
  #  sc = sc |> SC.assert!([{:detected,x}])
  #  {sc,true}
  #end

  defp verify(_sc,fact) do
    dead_end "don't know how to verify fact #{inspect fact}"
  end

  defp force(sc,{:file_meta, path, :file, _uid, _gid, _mode, _flags, _size, sha256}) do
    force(sc,{:sha256,path,sha256})
  end

  force_fun {:running, {:svc,svc}}, "#{@name}: starting service #{svc}.", ~s(service "#{svc}" onestart)
  force_fun {:installed,{:pkg,pkg_name,pkg_ver}}, "#{@name}: installing pkg #{pkg_name}-#{pkg_ver}", ~s(pkg install -y "#{pkg_name}-#{pkg_ver}")

  defp force(sc,{:sha256,dst_file,sha}) do
    src_file = Path.join [Cfg.cache_dir,sha]
    unless File.exists? src_file do
      dead_end "Don't know how to force #{dst_file} to have sha=#{sha}"
    end
    Logger.info "#{@name}: forcing #{dst_file} to have sha=#{sha}"
    sc |> SC.put_file!(File.read!(src_file),dst_file)
    {sc,true}
  end

  defp force(_sc,fact) do
    dead_end "don't know how to force fact #{inspect fact}"
  end

  defp dead_end(msg) do
    Logger.error "#{@name} in a dead end: #{msg}"
    exit {:dead_end,msg}
  end

  defp tmp_file(options\\[]) do
    dir = options[:dir] || System.tmp_dir!
    prefix = options[:prefix] || "symconfig-"
    salt = :erlang.now |> :erlang.phash2
    fpath = Path.join([dir,"#{prefix}#{salt}"])
    case File.exists?(fpath) do
      true -> tmp_file
      false -> fpath
    end
  end

  defp tmp_file_open(options\\[],f_options\\[:write,:binary]) do
    fpath = tmp_file options
    f = File.open!(fpath,f_options)
    File.chmod! fpath, 0o400
    {fpath,f}
  end

  def sha256_string(str) do
    {fpath,f} = tmp_file_open
    :ok = IO.binwrite f, str
    :ok = File.close(f)
    sha = sha256 fpath
    File.rm! fpath
    sha
  end

  def sha256(fpath) do
    {sha,0} = System.cmd "sha256", ["-q",fpath]
    sha |> String.rstrip
  end
end
