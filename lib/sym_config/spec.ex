defmodule SymConfig.Spec do

  defmacro __using__ _opts do
    quote do
      alias SymConfig, as: SC
      require Logger
      require SC
      import SC.Spec

      def provision do
        sc = spec

        #Logger.debug "required:"
        #sc |> SC.required |> Enum.each(fn x -> Logger.debug "     #{inspect x}" end)
        #Logger.debug "justified:"
        #sc |> SC.justified |> Enum.each(fn x -> Logger.debug "     #{inspect x}" end)

        {time,sc} = :timer.tc(fn -> sc |> SC.provision!(&Actor.FreeBSD.act/2) end)
        Logger.debug "Machine provisioned in #{time/1000000}s"

        # assert everything went well
        true = sc |> SC.in_state(:acceptable_state)
        #{sc,true} = sc |> SC.mtree_test
        sc
      end

    end
  end

  def latest(x), do: {:latest,x}
  def installed(x), do: {:installed,x}
  def running(x), do: {:running,x}
  def svc_running(x), do: {:running,svc(x)}
  def svc(x), do: {:svc,x}
  def cfg_file(x), do: {:managed,{:file,x}}
  def pkg_installed(x,version\\:latest), do: {:installed,pkg(x,version)}
  def pkg_dep(p1,p2), do: {:pkg_depends,p1,p2}
  def pkg(x,version\\:latest), do: {:pkg,x,version}
  def depends(x,y), do: {:depends,x,y}
  def os_installed(x,version\\:latest), do: {:installed,os(x,version)}
  def os(x,version\\:latest), do: {:os,x,version}
  def want(x), do: {:want, x}
  def peex(src_file,dst_file,patch_id,varset), do:
    {:peex_managed,src_file,dst_file,patch_id,varset}
  def dir(fileset,path,uid,gid,mode,flags), do:
    {:file_meta,fileset,path,:dir,uid,gid,mode,flags,nil,nil}
  def file(fileset,path,uid,gid,mode,flags,size,sha256), do:
    {:file_meta,fileset,path,:file,uid,gid,mode,flags,size,sha256}
  def patch(id,ver), do:
    {:patch,id,ver}
  def varset_hash(varset,hash), do:
    {:varset_hash,varset,hash}
end
