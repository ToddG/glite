-module(glite_child_ffi).
-include("../../gleam_otp/include/gleam@otp@supervision_ChildSpecification.hrl").
-include("../../gleam_otp/include/gleam@otp@supervision_Worker.hrl").
-include("../../gleam_otp/include/gleam@otp@actor_Started.hrl").
-export([start_child/2, start_child_callback/1, delete_child/2,
        restart_child/2, terminate_child/2]).

-spec start_child(SupPid::pid(), #child_specification{}) ->
    {ok, {supervised_child, {Child::pid(), Id::integer()}}} | {error, term()}.
start_child(SupPid, #child_specification{start = Start, child_type = ChildType,
                                         restart = Restart, significant = Significant}) ->
    MFA = {glite_child_ffi, start_child_callback, [Start]},
    {Type, Shutdown} =
        case ChildType of
            #worker{shutdown_ms = MS} when MS > 0 -> {worker, MS};
            #worker{} -> {worker, infinity};
            _ -> {supervisor, infinity}
        end,
    Id =  unique_positive_integer(),
    ErlChildSpec =
        #{ id => Id,
           start => MFA,
           restart => Restart,
           significant => Significant,
           type => Type,
           shutdown => Shutdown
         },

    case supervisor:start_child(SupPid, ErlChildSpec) of
        {ok, Child} -> {ok, {supervised_child, Child, Id}};
        {ok, Child, _Info} -> {ok, {supervised_child, Child, Id}};
        {error, Error} -> {error, Error}
    end.

%%   Callback used by the Erlang supervisor module.
start_child_callback(StartFun) ->
    case StartFun() of
        {ok, #started{pid = Pid}} -> {ok, Pid};
        {error, Error} -> {error, {actor, Error}}
    end.

delete_child(SupPid, Id) ->
    case supervisor:delete_child(SupPid, Id) of
        ok -> {ok, nil};
        {error, Error} -> {error, Error}
    end.

restart_child(SupPid, Id) ->
    case supervisor:restart_child(SupPid, Id) of
        {ok, Child} -> {ok, Child};
        {ok, Child, _Info} -> {ok, Child};
        {error, Error} -> {error, Error}
    end.

terminate_child(SupPid, Id) ->
    case supervisor:terminate_child(SupPid, Id) of
        ok -> {ok, nil};
        {error, Error} -> {error, Error}
    end.

%% Internal functions
%% Reserve first 2000 for indexed static processes.
unique_positive_integer() ->
    erlang:unique_integer([positive]) + 2000.

