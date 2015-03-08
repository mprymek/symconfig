-module(symconfig_helper).

-export([
  error/1
]).

error(Err) ->
%  io:format("Symconfig.pl error: ~p~n",[Err]),
  Msg = io_lib:format("Symconfig.pl error: ~p~n",[Err]),
  'Elixir.Logger':log(error,Msg),
%  fail.
%  throw(Err).
  exit({symconfig_error,Err}).
