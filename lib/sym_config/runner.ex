defmodule SymConfig.Runner do
  require Logger

  @main_script_mod Spec

  def run(script,fun) do
    Logger.info "Starting provisioning with script #{inspect script}"
    has_main_mod = Code.load_file(script)
    |> Enum.any?(fn {mod,_} -> mod==@main_script_mod end)
    unless has_main_mod do
      Logger.error "Script does not contain #{@main_script_mod} module."
      exit {:missing_module,@main_script_mod}
    end
    apply @main_script_mod, fun, []
  end

end
