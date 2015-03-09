defmodule FreeBSD do
  @moduledoc """
  This module simulates facts generated from mtree files. For mtree files see: https://github.com/mprymek/mtrees
  """
  import SymConfig.Spec

  @latest "10.1-RELEASE-p4-amd64"

  def load(sc,"10.1-RELEASE-p4-amd64-vagrant") do
    os_ver="10.1-RELEASE-p4-amd64"
    facts = common(os_ver)++[
      file(os(:freebsd,os_ver),"/etc/ssh/sshd_config",0,0,644,[:uarch],4046,"4355a9d2f26b3329f0b0008fe9d63b4f03b82235cc0bc8c0448366f18b384ce1"),
    ]
    sc |> SymConfig.assert!(facts) |> load_latest
  end
  def load(sc,os_ver="10.1-RELEASE-p4-amd64") do
    facts = common(os_ver)++[
      file(os(:freebsd,os_ver),"/etc/ssh/sshd_config",0,0,644,[:uarch],4046,"26748c51687fe4f09ac6c8ace864d0c545f1fc0aa059bb9bffd80f80c0d62d85"),
    ]
    sc |> SymConfig.assert!(facts) |> load_latest
  end
  def load(_,ver) do
    raise "FreeBSD ver. #{inspect ver} is not available"
  end

  defp common(os_ver="10.1-RELEASE-p4-amd64") do
    my_os = os :freebsd, os_ver
    [
      dir(my_os,"/",0,0,755,[:uarch]),
      dir(my_os,"/etc",0,0,755,[:uarch]),
      dir(my_os,"/etc/ssh",0,0,755,[:uarch]),
      # original version
      # vagrant version
      dir(my_os,"/usr",0,0,755,[:uarch]),
      dir(my_os,"/usr/local",0,0,755,[:uarch]),
      dir(my_os,"/usr/local/etc",0,0,755,[:uarch]),
      dir(my_os,"/usr/sbin",0,0,755,[:uarch]),
      file(my_os,"/usr/sbin/sshd",0,0,555,[:uarch],297792,"819b1edb37352186f3fdac8fb61010d4008cf93b7093cea6063615c785bfd1ae"),
      want(installed(my_os)),
    ]
  end

  defp load_latest(sc) do
     sc |> SymConfig.assert!(latest(os(:freebsd,@latest)))
  end
end

defmodule Repo do
  @moduledoc """
  This module simulates facts generated from package repostory.
  """
  import SymConfig.Spec

  def load(sc) do
    nginx = pkg("nginx","1.6.2_1,2")
    sc |> SymConfig.assert!([
      # latest version of packages are...
      latest(nginx),

      # packages files are...
      dir(nginx,"/usr/local/etc/nginx",0,0,755,[:uarch]),
      file(nginx,"/usr/local/etc/nginx/nginx.conf-dist",0,0,644,[:uarch],2693,"6418ea5b53e0c2b4e9baa517fce7ccf7619db03af68de7445dccb2c857978a4a"),

      # package dependencies are...
      pkg_dep(nginx, pkg("expat","2.1.0_2")),
      pkg_dep(nginx, pkg("openldap-sasl-client","2.4.40_1")),
      pkg_dep(nginx, pkg("pcre","8.35_2")),
      pkg_dep(pkg("openldap-sasl-client","2.4.40_1"), pkg("cyrus-sasl","2.1.26_9")),
    ])
  end
end

defmodule Sshd do
  import SymConfig.Spec
  alias SymConfig, as: SC
  require SC
  require Exlog

  def load(sc) do
    my_cfg = cfg_file "/etc/ssh/sshd_config"
    my_svc = svc_running "sshd"
    [[Os: wos, Ver: wos_ver]] = sc |> SC.query( want(installed(os(Os,Ver))) )
    sc |> SC.assert!([
      peex("/etc/ssh/sshd_config","/etc/ssh/sshd_config","patch-sshd_config",:sshd),
      depends(my_svc,my_cfg),
      depends(my_cfg,os_installed(wos,wos_ver)),
      want(my_svc),
    ])
  end
end

defmodule Nginx do
  import SymConfig.Spec

  def load(sc) do
    my_cfg = cfg_file "/usr/local/etc/nginx/nginx.conf"
    my_svc = svc_running "nginx"
    my_pkg = pkg_installed "nginx"
    sc |> SymConfig.assert!([
      peex("/usr/local/etc/nginx/nginx.conf-dist","/usr/local/etc/nginx/nginx.conf","patch-nginx.conf",:nginx),
      depends(my_svc,my_pkg),
      depends(my_svc,my_cfg),
      depends(my_cfg,my_pkg),
      want(my_svc),
    ])
  end
end

defmodule Spec do
  use SymConfig.Spec
  require Logger
  require Exlog

  @host "127.0.0.1"
  @user "root"
  @port 2222

  @variables %{
      nginx: [
        port: 80,
        server: "www.example.com",
      ],
      sshd: [
        ports: [22,3333],
      ],
    }

  @os_ver "10.1-RELEASE-p4-amd64-vagrant"

  def spec do
    sc = SC.init(@variables,@host, @user, @port, [silently_accept_hosts: true])
       |> global_config
       |> Repo.load
       |> FreeBSD.load(@os_ver)
       |> Nginx.load
       |> Sshd.load
  end

  def global_config(sc) do
    sc = sc |> SC.assert!([
      latest(patch("patch-nginx.conf","0001")),
      latest(patch("patch-sshd_config","0001")),
    ])
    sc = @variables |> Enum.reduce(sc,fn
      {varset,content},sc ->
        sc |> SC.assert!(varset_hash(varset,:erlang.phash2(content)))
    end)
  end
end
