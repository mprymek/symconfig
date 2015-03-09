defmodule HighlevelTest do
  use ExUnit.Case, async: false
  require Logger
  require Exlog
  alias SymConfig, as: SC
  require SC
  import SymConfig.Spec, only: [varset_hash: 2]

  @host "127.0.0.1"
  @user "root"
  @port 2222

  @vars %{
      nginx: [
        port: 80,
        server: "www.example.com",
      ],
      sshd: [
        ports: [22,3333],
      ],
    }

  setup_all do
    os_ver = "10.1-RELEASE-p4-amd64"

    vars_hashes = @vars |> Enum.map(fn
      {varset,content} ->
        varset_hash(varset,:erlang.phash2(content))
    end)
    Logger.debug "vars_hashes = #{inspect vars_hashes, [pretty: true]}"

    sc = SC.init(@vars, @host, @user, @port, [silently_accept_hosts: true])
         |> SC.db_cache_or_fn("example3", fn sc ->
           sc = sc
              #|> SC.load_mtree({:os,:freebsd,os_ver},"test/fixtures/priv/freebsd-#{os_ver}.mtree")
              #|> SC.load_pkgdeps("test/fixtures/priv/repo-gosw.pkgdeps")
              |> SC.load_pkgdeps("test/fixtures/priv/repo-min-nginx.pkgdeps")
              #|> SC.load_pl("test/fixtures/priv/repo-gosw-deps.pl")
           sc.edb
         end)
         |> SC.assert!(vars_hashes)

    {:ok, %{sc: sc, os_ver: os_ver}}
  end

  test "connect to server" do
    sc = SC.init @vars, @host, @user, @port, [silently_accept_hosts: true]

    {sc,res} = sc |> SC.cmd("echo xyz abc")
    assert res == {0,"xyz abc\n"}

    {sc,res} = sc |> SC.cmd("echo def ghi")
    assert res == {0,"def ghi\n"}

    sc = sc |> SC.close
  end

  @tag :provision1
  test "provision 1", %{sc: sc, os_ver: os_ver} do
    # assert there are no trivial loops in package dependencies
    res = sc |> SC.query( pkg_depends(X,X) )
    assert res==[]

    res = sc |> SC.query( pkg_depends_r(pkg("nginx","1.6.2_1,2"), X) )
             |> Enum.sort
    assert res==[[X: {:pkg, "cyrus-sasl", "2.1.26_9"}], [X: {:pkg, "expat", "2.1.0_2"}],
                [X: {:pkg, "openldap-sasl-client", "2.4.40_1"}],[X: {:pkg, "pcre", "8.35_2"}]]

    my_os = {:os, :freebsd, "10.1-RELEASE-p4-amd64"}
    nginx_pkg = {:pkg,"nginx","1.6.2_1,2"}
    sc = sc |> SC.assert!([
      {:file_meta,my_os,"/",:dir,0,0,755,[:uarch],nil,nil},
      {:file_meta,my_os,"/usr",:dir,0,0,755,[:uarch],nil,nil},
      {:file_meta,my_os,"/usr/local",:dir,0,0,755,[:uarch],nil,nil},
      {:file_meta,my_os,"/usr/local/etc",:dir,0,0,755,[:uarch],nil,nil},
      {:latest,nginx_pkg},
      {:file_meta,nginx_pkg, "/usr/local/etc/nginx", :dir, 0, 0, 755, [:uarch], nil, nil},
      {:file_meta,nginx_pkg,"/usr/local/etc/nginx/nginx.conf-dist",:file,0,0,644,[:uarch],2693,"6418ea5b53e0c2b4e9baa517fce7ccf7619db03af68de7445dccb2c857978a4a"},
      {:latest,{:patch,"patch-nginx.conf","0001"}},
      {:peex_managed,"/usr/local/etc/nginx/nginx.conf-dist","/usr/local/etc/nginx/nginx.conf","patch-nginx.conf",:nginx},
      {:patch_cache, "6418ea5b53e0c2b4e9baa517fce7ccf7619db03af68de7445dccb2c857978a4a", "patch-nginx.conf", "3360af05330d4a6c0a575f820aec57edac19f3de9053941233920ac7d1ea0230"},
      {:eex_cache, "3360af05330d4a6c0a575f820aec57edac19f3de9053941233920ac7d1ea0230", 69552268, 2699, "8efafdf496494b41f20a7c78d2b009c0d172480517b0af6eabb4052b41be7c04"},
      {:depends,{:running,{:svc,"nginx"}},{:installed,{:pkg,"nginx",:latest}}},
      {:depends,{:running,{:svc,"nginx"}},{:managed,{:file,"/usr/local/etc/nginx/nginx.conf"}}},
      {:depends,{:managed,{:file,"/usr/local/etc/nginx/nginx.conf"}},{:installed,{:pkg,"nginx",:latest}}},
      {:want,{:running,{:svc,"nginx"}}},
      {:want,{:installed,my_os}},
    ])

    ##res = sc |> SC.query({:pkg_depends, {:x},{:y}})
    ##res |> Enum.each(fn [x: x, y: y] -> IO.puts "#{inspect x} #{inspect y}" end)

    #res = sc |> SC.query({:required, {:x}})
    #Logger.info "Required: #{inspect res}"
    #res = sc |> SC.query({:justified, {:x}})
    #Logger.info "Justified: #{inspect res}"
    #assert false

    #{_,{true,res}} = sc.edb |> Exlog.prove( file_meta(A,"/bin/sh",B,C,D,E,F,G,H) )
    #res = sc |> SC.query({:file_meta, {:FileSet}, {:Path}, {:Type}, {:Uid}, {:Gid}, {:Mode}, {:Flags}, {:Size}, {:Sha}})
    #res = sc |> SC.query({:justified, {:x}})
    #assert res==nil

    {time,sc} = :timer.tc(fn -> sc |> SC.provision!(&Actor.FreeBSD.act/2) end)
    Logger.debug "Machine provisioned in #{time/1000000}s"
    assert sc |> SC.in_state(:acceptable_state)

    {sc,res} = sc |> SC.mtree_test
    assert res
  end

  def svc(x), do: {:running,{:svc,x}}
  def cfg(x), do: {:managed,{:file,x}}
  def pkg(x,version\\:latest), do: {:installed,{:pkg,x,version}}
  def depends(x,y), do: {:depends,x,y}
  def os(x,version\\:latest), do: {:installed,{:os,x,version}}
  def want(x), do: {:want, x}

  def www_server(sc) do
    my_cfg = cfg "/usr/local/etc/nginx/nginx.conf"
    my_svc = svc "nginx"
    my_pkg = pkg "nginx"
    sc |> SC.assert!([
      {:peex_managed,"/usr/local/etc/nginx/nginx.conf-dist","/usr/local/etc/nginx/nginx.conf","patch-nginx.conf",:nginx},
      depends(my_svc,my_pkg),
      depends(my_svc,my_cfg),
      depends(my_cfg,my_pkg),
      want(my_svc),
    ])
  end

  def sshd_server(sc) do
    my_cfg = cfg "/etc/ssh/sshd_config"
    my_svc = svc "sshd"
    [[Os: wos, Ver: wos_ver]] = sc |> SC.query( want(installed(os(Os,Ver))) )
    sc |> SC.assert!([
      {:peex_managed,"/etc/ssh/sshd_config","/etc/ssh/sshd_config","patch-sshd_config",:sshd},
      depends(my_svc,my_cfg),
      depends(my_cfg,os(wos,wos_ver)),
      want(my_svc),
    ])
  end

  def freebsd(sc,version\\:latest) do
    my_os = {:os,:freebsd,"10.1-RELEASE-p4-amd64"}
    sc |> SC.assert!([
      {:file_meta,my_os,"/",:dir,0,0,755,[:uarch],nil,nil},
      {:file_meta,my_os,"/etc",:dir,0,0,755,[:uarch],nil,nil},
      {:file_meta,my_os,"/etc/ssh",:dir,0,0,755,[:uarch],nil,nil},
      # original version
      #{:file_meta,my_os,"/etc/ssh/sshd_config",:file,0,0,644,[:uarch],4046,"26748c51687fe4f09ac6c8ace864d0c545f1fc0aa059bb9bffd80f80c0d62d85"},
      # vagrant version
      {:file_meta,my_os,"/etc/ssh/sshd_config",:file,0,0,644,[:uarch],4046,"4355a9d2f26b3329f0b0008fe9d63b4f03b82235cc0bc8c0448366f18b384ce1"},
      {:file_meta,my_os,"/usr",:dir,0,0,755,[:uarch],nil,nil},
      {:file_meta,my_os,"/usr/local",:dir,0,0,755,[:uarch],nil,nil},
      {:file_meta,my_os,"/usr/local/etc",:dir,0,0,755,[:uarch],nil,nil},
      {:file_meta,my_os,"/usr/sbin",:dir,0,0,755,[:uarch],nil,nil},
      {:file_meta,my_os,"/usr/sbin/sshd",:file,0,0,555,[:uarch],297792,"819b1edb37352186f3fdac8fb61010d4008cf93b7093cea6063615c785bfd1ae"},
      want(os(:freebsd,version)),
    ])
  end

  def repo(sc) do
    pkg1={:pkg,"nginx","1.6.2_1,2"}
    sc |> SC.assert!([
      {:latest,{:pkg,"nginx","1.6.2_1,2"}},
      {:file_meta,pkg1,"/usr/local/etc/nginx",:dir,0,0,755,[:uarch],nil,nil},
      {:file_meta,pkg1,"/usr/local/etc/nginx/nginx.conf-dist",:file,0,0,644,[:uarch],2693,"6418ea5b53e0c2b4e9baa517fce7ccf7619db03af68de7445dccb2c857978a4a"},
    ])
  end

  def global_config(sc) do
    sc |> SC.assert!([
      {:latest,{:os,:freebsd,"10.1-RELEASE-p4-amd64"}},
      {:latest,{:patch,"patch-nginx.conf","0001"}},
      {:latest,{:patch,"patch-sshd_config","0001"}},
    ])
  end

  @tag :provision2
  test "provision 2", %{sc: sc} do
    sc = sc |> SC.assert!([
      # nginx.conf
      {:patch_cache, "6418ea5b53e0c2b4e9baa517fce7ccf7619db03af68de7445dccb2c857978a4a",
                     "patch-nginx.conf", "3360af05330d4a6c0a575f820aec57edac19f3de9053941233920ac7d1ea0230"},
      {:eex_cache,   "3360af05330d4a6c0a575f820aec57edac19f3de9053941233920ac7d1ea0230",
                     69552268, 2699, "8efafdf496494b41f20a7c78d2b009c0d172480517b0af6eabb4052b41be7c04"},
      {:patch_cache, "4355a9d2f26b3329f0b0008fe9d63b4f03b82235cc0bc8c0448366f18b384ce1",
                     "patch-sshd_config",
                     "19dabd66195b176ef39d90f8e1eb19d9cc0b31a77402066423171b5ca5e8b974"},
      {:eex_cache,   "19dabd66195b176ef39d90f8e1eb19d9cc0b31a77402066423171b5ca5e8b974",
                     106440519, 4046,
                     "63cfe919e32b41d766416b2354eb816ffa6dd0d4608ee2f03e44ba964398df5a"},
    ]) |> global_config
       |> repo
       |> freebsd
       |> www_server
       |> sshd_server

    assert sc |> SC.required |> Enum.sort == [
      {:installed, {:os, :freebsd, "10.1-RELEASE-p4-amd64"}},
      {:installed, {:pkg, "nginx", "1.6.2_1,2"}},
      {:running, {:svc, "nginx"}}, {:running, {:svc, "sshd"}},
      {:file_meta, "/etc/ssh/sshd_config", :file, 0, 0, 644, [:uarch], 4046, "63cfe919e32b41d766416b2354eb816ffa6dd0d4608ee2f03e44ba964398df5a"},
      {:file_meta, "/usr/local/etc/nginx/nginx.conf", :file, 0, 0, 644, [:uarch], 2699, "8efafdf496494b41f20a7c78d2b009c0d172480517b0af6eabb4052b41be7c04"},
    ]

    assert sc |> SC.justified |> Enum.sort == [
      {:installed, {:os, :freebsd, "10.1-RELEASE-p4-amd64"}}, {:installed, {:pkg, "nginx", "1.6.2_1,2"}}, {:running, {:svc, "nginx"}}, {:running, {:svc, "sshd"}},
      {:file_meta, "/", :dir, 0, 0, 755, [:uarch], nil, nil}, {:file_meta, "/etc", :dir, 0, 0, 755, [:uarch], nil, nil},
      {:file_meta, "/etc/ssh", :dir, 0, 0, 755, [:uarch], nil, nil},
      {:file_meta, "/etc/ssh/sshd_config", :file, 0, 0, 644, [:uarch], 4046, "63cfe919e32b41d766416b2354eb816ffa6dd0d4608ee2f03e44ba964398df5a"},
      {:file_meta, "/usr", :dir, 0, 0, 755, [:uarch], nil, nil}, {:file_meta, "/usr/local", :dir, 0, 0, 755, [:uarch], nil, nil},
      {:file_meta, "/usr/local/etc", :dir, 0, 0, 755, [:uarch], nil, nil}, {:file_meta, "/usr/local/etc/nginx", :dir, 0, 0, 755, [:uarch], nil, nil},
      {:file_meta, "/usr/local/etc/nginx/nginx.conf", :file, 0, 0, 644, [:uarch], 2699, "8efafdf496494b41f20a7c78d2b009c0d172480517b0af6eabb4052b41be7c04"},
      {:file_meta, "/usr/local/etc/nginx/nginx.conf-dist", :file, 0, 0, 644, [:uarch], 2693, "6418ea5b53e0c2b4e9baa517fce7ccf7619db03af68de7445dccb2c857978a4a"},
      {:file_meta, "/usr/sbin", :dir, 0, 0, 755, [:uarch], nil, nil},
      {:file_meta, "/usr/sbin/sshd", :file, 0, 0, 555, [:uarch], 297792, "819b1edb37352186f3fdac8fb61010d4008cf93b7093cea6063615c785bfd1ae"},
    ]

    assert sc |> SC.required_files |> Enum.sort == [
      {:file_meta, "/etc/ssh/sshd_config", :file, 0, 0, 644, [:uarch], 4046, "63cfe919e32b41d766416b2354eb816ffa6dd0d4608ee2f03e44ba964398df5a"},
      {:file_meta, "/usr/local/etc/nginx/nginx.conf", :file, 0, 0, 644, [:uarch], 2699, "8efafdf496494b41f20a7c78d2b009c0d172480517b0af6eabb4052b41be7c04"},
    ]

    mtree_lines = sc |> SC.mtree |> Enum.sort
    assert mtree_lines == [
      ". type=dir uid=0 gid=0 mode=0755 flags=uarch\n", "./etc type=dir uid=0 gid=0 mode=0755 flags=uarch\n", "./etc/ssh type=dir uid=0 gid=0 mode=0755 flags=uarch\n",
      "./etc/ssh/sshd_config type=file uid=0 gid=0 mode=0644 size=4046 sha256digest=63cfe919e32b41d766416b2354eb816ffa6dd0d4608ee2f03e44ba964398df5a flags=uarch\n",
      "./usr type=dir uid=0 gid=0 mode=0755 flags=uarch\n", "./usr/local type=dir uid=0 gid=0 mode=0755 flags=uarch\n",
      "./usr/local/etc type=dir uid=0 gid=0 mode=0755 flags=uarch\n", "./usr/local/etc/nginx type=dir uid=0 gid=0 mode=0755 flags=uarch\n",
      "./usr/local/etc/nginx/nginx.conf type=file uid=0 gid=0 mode=0644 size=2699 sha256digest=8efafdf496494b41f20a7c78d2b009c0d172480517b0af6eabb4052b41be7c04 flags=uarch\n",
      "./usr/local/etc/nginx/nginx.conf-dist type=file uid=0 gid=0 mode=0644 size=2693 sha256digest=6418ea5b53e0c2b4e9baa517fce7ccf7619db03af68de7445dccb2c857978a4a flags=uarch\n",
      "./usr/sbin type=dir uid=0 gid=0 mode=0755 flags=uarch\n",
      "./usr/sbin/sshd type=file uid=0 gid=0 mode=0555 size=297792 sha256digest=819b1edb37352186f3fdac8fb61010d4008cf93b7093cea6063615c785bfd1ae flags=uarch\n",
    ]


    #res = sc |> SC.query({:file_meta, {:os,:freebsd,os_ver}, {:Path}, {:Type}, {:Uid}, {:Gid}, {:Mode}, {:Flags}, {:Size}, {:Sha}})
    #assert res==nil

    {time,sc} = :timer.tc(fn -> sc |> SC.provision!(&Actor.FreeBSD.act/2) end)
    Logger.debug "Machine provisioned in #{time/1000000}s"
    assert sc |> SC.in_state(:acceptable_state)

    {sc,res} = sc |> SC.mtree_test
    assert res
  end

  @tag :provision3
  test "provision 3", %{sc: sc} do
    sc = sc
       |> global_config
       |> repo
       |> freebsd
       |> www_server
       |> sshd_server

    #assert sc |> SC.query( os_layer(file_meta(Path,Type,Uid,Gid,Mode,Flags,Size,Sha256)) ) == nil
    #assert sc |> SC.required |> Enum.sort == nil

    {time,sc} = :timer.tc(fn -> sc |> SC.provision!(&Actor.FreeBSD.act/2) end)
    Logger.debug "Machine provisioned in #{time/1000000}s"
    assert sc |> SC.in_state(:acceptable_state)

    {sc,res} = sc |> SC.mtree_test
    assert res
  end
end
