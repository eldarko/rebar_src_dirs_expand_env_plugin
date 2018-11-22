-module(rebar_src_dirs_expand_env).

-export([init/1]).

-spec init(rebar_state:t()) -> {ok, rebar_state:t()}.
init(State) ->
  {ok, expand_state(State)}.

expand_state(State) ->
  lists:foldl(
    fun(Profile, S) ->
      expand_profile(Profile, S)
    end,
    State,
    rebar_state:current_profiles(State)).

expand_profile(Profile, State) ->
  Key = {parsed_deps, Profile},

  case rebar_state:get(State, Key, undef) of
    undef -> State;
    Deps  -> rebar_state:set(State, Key, expand_deps(Deps, Profile, State))
  end.

expand_deps(Deps, Profile, State) ->
  [expand_app(Dep, Profile, State) || Dep <- Deps].

expand_app(App, _, _) when app_info_t =/= element(1, App) ->
  App;
expand_app(App, Profile, State) ->
  case rebar_app_info:get(App, src_dirs, undef) of
    undef ->
      App;

    SrcDirs ->
      NewSrcDirs = [expand_env_variables(D, State) || D <- SrcDirs],
      NewApp     = rebar_app_info:set(App, src_dirs, NewSrcDirs),

      expand_app_deps(NewApp, Profile, State)
  end.

expand_app_deps(App, Profile, State) ->
  Key = {deps, Profile},

  case rebar_app_info:get(App, Key, undef) of
    undef ->
      App;

    Deps ->
      NewDeps = [expand_app(A, Profile, State) || A <- Deps],
      rebar_app_info:set(App, Key, NewDeps)
  end.

expand_env_variables(Input, State) ->
  lists:foldl(
    fun({Var, Value}, Input0) ->
      rebar_utils:expand_env_variable(Input0, Var, Value)
    end,
    Input,
    rebar_env:create_env(State)).
