defmodule InferenceTest do
  use ExUnit.Case, async: true
  use Exlog
  require Logger
  alias Symconfig.Inference, as: I

  setup_all do
    e0 = Exlog.new
        |> consult!("priv/symconfig.pl")
    e1 = Exlog.new
        |> consult!("priv/symconfig.pl")
        |> consult!("priv/example1.pl")
    e2 = Exlog.new
        |> consult!("priv/symconfig.pl")
        |> consult!("priv/example2.pl")
    {:ok, %{e0: e0, e1: e1, e2: e2}}
  end

  @tag :example1
  test "Iteratively achieve the acceptable state in example1", %{e1: e} do
    assert e |> I.required |> Enum.sort == [
      installed: {:pkg, 'nginx', '1.6.2_1,2'},
      managed: {:file, '/usr/local/etc/nginx/nginx.conf'},
      running: {:svc, 'nginx'},
    ]

    [{:verify,ta1}] = e |> I.to_achieve(:acceptable_state)
    assert ta1 == {:installed, {:pkg, 'nginx', '1.6.2_1,2'}}

    {e, {true,[]}} = e |> e_prove( {:assert,{:detected,ta1}} )

    [{:verify,ta1}] = e |> I.to_achieve(:acceptable_state)
    assert ta1 == {:sha256, '/usr/local/etc/nginx/nginx.conf', 'deadbeaf'}

    {e, {true,[]}} = e |> e_prove( {:assert,{:detected,ta1}} )

    [{:verify,ta1}] = e |> I.to_achieve(:acceptable_state)
    assert ta1 == {:running, {:svc, 'nginx'}}

    {e, {true,[]}} = e |> e_prove( {:assert,{:detected,ta1}} )

    ta = e |> I.to_achieve(:acceptable_state)
    assert ta == []
  end

  @tag :example1
  test "Find a way to the acceptable state in example1", %{e1: e} do
    way = e |> I.all_to_achieve(:acceptable_state)
    assert way == [
      [verify: {:installed, {:pkg, 'nginx', '1.6.2_1,2'}}],
      [verify: {:sha256, '/usr/local/etc/nginx/nginx.conf', 'deadbeaf'}],
      [verify: {:running, {:svc, 'nginx'}}],
    ]
  end

  def get_and_reach(e,state) do
    tgt = e |> I.to_achieve(state)
    e = tgt |> Enum.reduce(e,fn
      {:verify,x},e ->
        {e, {true,[]}} = e |> e_prove( {:assert,{:detected,x}} )
        e
    end)
    {e,tgt}
  end

  @tag :example2
  test "iteratively achieve the acceptable state in example2", %{e2: e} do
    assert e |> I.required |> Enum.sort == [
      installed: {:os, :freebsd, '10.1-RELEASE-p5'},
      installed: {:pkg, 'nginx', '1.6.2_1,2'},
      managed: {:file, '/etc/ssh/sshd_config'},
      managed: {:file, '/usr/local/etc/nginx/nginx.conf'},
      running: {:svc, 'nginx'}, running: {:svc, 'sshd'}
    ]

    {e, tgt} = get_and_reach e, :acceptable_state
    assert length(tgt) == 2
    assert {:verify, {:installed, {:os, :freebsd, '10.1-RELEASE-p5'}}} in tgt
    assert {:verify, {:installed, {:pkg, 'nginx', '1.6.2_1,2'}}} in tgt


    {e, tgt} = get_and_reach e, :acceptable_state
    assert length(tgt) == 2
    assert {:verify, {:sha256, '/usr/local/etc/nginx/nginx.conf', 'deadbeaf'}} in tgt
    assert {:verify, {:sha256, '/etc/ssh/sshd_config', 'ba11ad'}} in tgt

    {e, tgt} = get_and_reach e, :acceptable_state
    assert length(tgt) == 2
    assert {:verify, {:running, {:svc, 'nginx'}}} in tgt
    assert {:verify, {:running, {:svc, 'sshd'}}} in tgt

    {e, tgt} = get_and_reach e, :acceptable_state
    assert length(tgt) == 0
  end

  #@tag :example2
  #test "find a way to the acceptable state in example2", %{e2: e} do
  #  way = e |> I.all_to_achieve(:acceptable_state)
  #  assert way == [
  #    [verify: {:sha256, '/etc/ssh/sshd_config', 'ba11ad'}, verify: {:installed, {:pkg, 'nginx', '1.6.2_1,2'}}],
  #    [verify: {:sha256, '/usr/local/etc/nginx/nginx.conf', 'deadbeaf'}, verify: {:running, {:svc, 'sshd'}}],
  #    [verify: {:running, {:svc, 'nginx'}}],
  #  ]
  #end


  @tag :pokusy
  test "", %{e0: e} do

  end
end
