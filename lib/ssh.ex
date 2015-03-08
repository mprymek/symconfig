defmodule Ssh.State do
  defstruct host: nil, port: nil, user: nil, options: nil, con: nil
end

defmodule Ssh do
  @moduledoc """
  To run command on server:

      server = Ssh.connect "192.168.1.2", "toor"
      {ret_code,data} = Ssh.cmd server, "ls /"
      Ssh.close server

  """
  require Logger
  alias Ssh.State
  alias SymConfig.Cfg

  def connect(host,user,port\\22,options\\[]) do
    Logger.debug "#{__MODULE__}: connecting to #{inspect host}"
    spawn_link(fn -> init %State{host: host, port: port, user: user, options: options} end)
  end

  def cmd(pid,cmd,timeout\\:infinity) when is_binary(cmd) do
    ref = make_ref
    send pid, {:cmd_sync,{self,ref},cmd}
    receive do
      {^ref,res} -> res
      after timeout -> raise "Timeout"
    end
  end

  def get_file!(pid,file,timeout\\:infinity) when is_binary(file) do
    ref = make_ref
    send pid, {:get_file!,{self,ref},file}
    receive do
      {^ref,{:ok,data}} -> data
      after timeout -> raise "Timeout"
    end
  end

  def put_file!(pid,data,file,timeout\\:infinity) when is_binary(data) and is_binary(file) do
    ref = make_ref
    send pid, {:put_file!,{self,ref},data,file}
    receive do
      {^ref,:ok} -> :ok
      after timeout -> raise "Timeout"
    end
  end

  def cmd_async(pid,cmd) when is_binary(cmd) do
    ref = make_ref
    send pid, {:cmd_sync,{self,ref},cmd}
    ref
  end

  def close(pid) do
    send pid, :close
    nil
  end

  def init(s=%State{}) do
    {:ok,con} = :ssh.connect String.to_char_list(s.host), s.port, [user: String.to_char_list(s.user),
      user_interaction: false, user_dir: String.to_char_list(Cfg.ssh_dir)]++s.options
    loop(%State{s|con: con})
  end

  defp loop(s=%State{}) do
    receive do
      {:cmd_sync,cref={_caller,_ref},cmd} when is_binary(cmd) ->
        chan = open_chan(s.con)
        spawn_link(fn ->
          cmd = cmd |> String.to_char_list
          :success = :ssh_connection.exec s.con, chan, cmd, 10000
          cmd_loop cref,{[],nil}
        end)
        loop s
      {:get_file!,{caller,ref},file} when is_binary(file) ->
        {:ok, chan} = :ssh_sftp.start_channel s.con
        spawn_link(fn ->
          {:ok,data} = :ssh_sftp.read_file chan, file
          :ok = :ssh_sftp.stop_channel chan
          send caller, {ref,{:ok,data}}
        end)
        loop s
      {:put_file!,{caller,ref},data,file} when is_binary(data) and is_binary(file) ->
        {:ok, chan} = :ssh_sftp.start_channel s.con
        spawn_link(fn ->
          :ok = :ssh_sftp.write_file chan, file, data
          :ok = :ssh_sftp.stop_channel chan
          send caller, {ref,:ok}
        end)
        loop s
      :close ->
        :ssh.close s.con
        :ok
      any ->
        Logger.error "Unexpected msg: #{inspect any}"
        loop s
    end
  end

  defp cmd_loop(cref={caller,ref},state={buff,ret_code}) do
    receive do
      {:ssh_cm, _con, {:data, _chan, _data_type, data}} ->
        cmd_loop cref, {[data|buff],ret_code}
      {:ssh_cm, _con, {:eof, _chan}} ->
        cmd_loop cref, state
      {:ssh_cm, _con, {:exit_status, _chan, status}} ->
        cmd_loop cref, {buff,status}
      {:ssh_cm, _con, {:closed, _chan}} ->
        data = buff |> Enum.reverse |> Enum.join
        send caller, {ref,{ret_code,data}}
        :ok
      any ->
        raise "Unexpected msg for channel: #{inspect any}"
    end
  end

  defp open_chan(con) do
    {:ok,chan} = :ssh_connection.session_channel con, 5000
    chan
  end

end
