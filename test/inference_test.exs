defmodule InferenceTest do
  use ExUnit.Case, async: true
  use Exlog
  require Logger
  alias SymConfig.Inference, as: I

  setup_all do
    e0 = Exlog.new
        |> consult!("priv/symconfig.pl")
    e1 = e0
        |> consult!("test/fixtures/priv/example1.pl")
    e2 = e0
        |> consult!("test/fixtures/priv/example2.pl")
    {:ok, %{e0: e0, e1: e1, e2: e2}}
  end

  @tag :example1i
  test "example1 iteratively", %{e1: e} do

    assert e |> I.required |> Enum.sort == [
      {:installed, {:pkg, 'nginx', '1.6.2_1,2'}},
      {:running, {:svc, 'nginx'}},
      {:file_meta, '/usr/local/etc/nginx/nginx.conf', :file, 0, 0, 644, [:uarch], 2701, 'deadbeaf'},
    ]

    [{:verify,ta1}] = e |> I.to_achieve(:acceptable_state)
    assert ta1 == {:installed, {:pkg, 'nginx', '1.6.2_1,2'}}

    {e, {true,[]}} = e |> e_prove( {:assert,{:detected,ta1}} )

    [{:verify,ta1}] = e |> I.to_achieve(:acceptable_state)
    assert ta1 == {:file_meta, '/usr/local/etc/nginx/nginx.conf', :file, 0, 0, 644, [:uarch], 2701, 'deadbeaf'}

    {e, {true,[]}} = e |> e_prove( {:assert,{:detected,ta1}} )

    [{:verify,ta1}] = e |> I.to_achieve(:acceptable_state)
    assert ta1 == {:running, {:svc, 'nginx'}}

    {e, {true,[]}} = e |> e_prove( {:assert,{:detected,ta1}} )

    ta = e |> I.to_achieve(:acceptable_state)
    assert ta == []
  end

  @tag :example1
  test "example1", %{e1: e} do
    way = e |> I.all_to_achieve(:acceptable_state)
    assert way == [
      [verify: {:installed, {:pkg, 'nginx', '1.6.2_1,2'}}],
      [verify: {:file_meta, '/usr/local/etc/nginx/nginx.conf', :file, 0, 0, 644, [:uarch], 2701, 'deadbeaf'}],
      [verify: {:running, {:svc, 'nginx'}}],
    ]
  end

  def get_and_reach(e,state) do
    tgt = e |> I.to_achieve(state)
    e = tgt |> Enum.reduce(e,fn
      {:verify,x},e ->
        {e, {true,[]}} = e |> e_prove( {:assert,{:detected,x}} )
        e
      {:manage,_x},_e ->
        raise "manage(...) not implemented"
    end)
    {e,tgt}
  end

  @tag :example2i
  test "example2 iteratively", %{e2: e} do
    #{e, res} = e |> prove_all( mngd_layer(X) )
    #{e, res} = e |> prove_all( os_pkg_layer(X) )
    #{e, res} = e |> prove_all( peex_managed(X,Y) )
    #assert res == nil

    assert e |> I.required |> Enum.sort == [
      {:installed, {:os, :freebsd, '10.1-RELEASE-p5'}},
      {:installed, {:pkg, 'nginx', '1.6.2_1,2'}},
      {:running, {:svc, 'nginx'}},
      {:running, {:svc, 'sshd'}},
      {:file_meta, '/etc/ssh/sshd_config', :file, 0, 0, 644, [:uarch], 4046, 'ba11ad'},
      {:file_meta, '/usr/local/etc/nginx/nginx.conf', :file, 0, 0, 644, [:uarch], 2701, 'deadbeaf'}
    ]

    {e, tgt} = get_and_reach e, :acceptable_state
    assert length(tgt) == 2
    assert {:verify, {:installed, {:os, :freebsd, '10.1-RELEASE-p5'}}} in tgt
    assert {:verify, {:installed, {:pkg, 'nginx', '1.6.2_1,2'}}} in tgt


    {e, tgt} = get_and_reach e, :acceptable_state
    assert length(tgt) == 2
    assert {:verify, {:file_meta, '/usr/local/etc/nginx/nginx.conf', :file, 0, 0, 644, [:uarch], 2701, 'deadbeaf'}} in tgt
    assert {:verify, {:file_meta, '/etc/ssh/sshd_config', :file, 0, 0, 644, [:uarch], 4046, 'ba11ad'}} in tgt

    {e, tgt} = get_and_reach e, :acceptable_state
    assert length(tgt) == 2
    assert {:verify, {:running, {:svc, 'nginx'}}} in tgt
    assert {:verify, {:running, {:svc, 'sshd'}}} in tgt

    {_e, tgt} = get_and_reach e, :acceptable_state
    assert length(tgt) == 0
  end

  @tag :example2
  test "example2", %{e2: e} do
    way = e |> I.all_to_achieve(:acceptable_state)
    assert way == [
      [verify: {:installed, {:os, :freebsd, '10.1-RELEASE-p5'}}, verify: {:installed, {:pkg, 'nginx', '1.6.2_1,2'}}],
      [verify: {:file_meta, '/usr/local/etc/nginx/nginx.conf', :file, 0, 0, 644, [:uarch], 2701, 'deadbeaf'},
       verify: {:file_meta, '/etc/ssh/sshd_config', :file, 0, 0, 644, [:uarch], 4046, 'ba11ad'}],
      [verify: {:running, {:svc, 'nginx'}}, verify: {:running, {:svc, 'sshd'}}],
    ]
  end

end
