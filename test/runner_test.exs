defmodule RunnerTest do
  use ExUnit.Case, async: false
  alias SymConfig.Runner

  @tag :runner
  test "run provision script" do
    Runner.run "test/fixtures/example4.exs", :provision
  end

end
