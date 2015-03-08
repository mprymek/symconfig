defmodule SymConfig.Cfg do

  def cache_dir, do:
    Application.get_env(:sym_config,:cache_dir,"priv/cache")

  def orig_dir, do:
    Application.get_env(:sym_config,:orig_dir,"priv/orig")

  def patches_dir, do:
    Application.get_env(:sym_config,:patches_dir,"priv/patches")

  def ssh_dir, do:
    Application.get_env(:sym_config,:ssh_dir,"priv/ssh")

  def templates_dir, do:
    Application.get_env(:sym_config,:templates_dir,"priv/templates")

end
