%%%-------------------------------------------------------------------
%%% @author sunb
%%% @copyright (C) 2018, SY
%%% @doc
%%%     AOI之九宫格算法
%%% @end
%%% Created : 29. 六月 2018 10:57
%%%-------------------------------------------------------------------
-module(aoi).
-author("sunb").

%% API
-export([enter_object/1, leave_object/1, move_object/3]).

-export([test/1, test/2]).

-include("common.hrl").

-define(GRID_WIDTH, 10).
-define(GRID_HEIGHT, 10).
-define(CONST_GRID_CALC, 10000).

-define(MAP_WIDTH, 600).
-define(MAP_HEIGHT, 400).

-define(DICT_MAP_OBJECTS, dict_map_objects).

-record(object, {
    id = 0,
    x = 0,
    y = 0,
    grid_id = 0
}).

%% @doc 进入
enter_object(Object) ->
    GridID = calc_grid_id(Object#object.x, Object#object.y),
    NewObject = Object#object{grid_id = GridID},
    AllObjects = add_map_objects(NewObject),
    NineGrids = get_nine_grids(GridID),
    AoiObjects = lists:foldl(fun(E, Acc) -> util:if_true(lists:member(E#object.grid_id, NineGrids), [E|Acc], Acc) end, [], AllObjects),
    AoiObjects.

%% @doc 移动
move_object(Object, Tx, Ty) ->
    OldGridID = Object#object.grid_id,

    NewGridID = calc_grid_id(Tx, Ty),
    NewObject = Object#object{x=Tx, y=Ty, grid_id = NewGridID},
    AllObjects = add_map_objects(NewObject),

    OldNineGrids = get_nine_grids(OldGridID),
    NewNineGrids = get_nine_grids(NewGridID),

    EnterGrids = NewNineGrids -- OldNineGrids,
    MoveGrids = NewNineGrids -- EnterGrids,
    LeaveGrids = OldNineGrids -- NewNineGrids,

    {EnterObjects, MoveObjects, LeaveObjects} = lists:foldl(fun(E, {EnterAcc, MoveAcc, LeaveAcc}=_Acc) ->
        handle_move_objects(lists:member(E#object.grid_id, EnterGrids), lists:member(E#object.grid_id, MoveGrids), lists:member(E#object.grid_id, LeaveGrids),
            E, EnterAcc, MoveAcc, LeaveAcc)
                             end, {[], [], []}, AllObjects),
    {EnterObjects, MoveObjects, LeaveObjects}.

%% @doc 离开
leave_object(Object) ->
    AllObjects = remove(Object),
    NineGrids = get_nine_grids(Object#object.grid_id),
    AoiObjects = lists:foldl(fun(E, Acc) -> util:if_true(lists:member(E#object.grid_id, NineGrids), [E|Acc], Acc) end, [], AllObjects),
    AoiObjects.

%% @doc 测试
%% Num  Cnt    Time(ms)
%% 1000 6104   161
%% 2000 22740  654
%% 3000 49393  1573
%% 4000 86801  2682
%% 5000 136292 4172
test(Num) ->
    test(Num, Num).
test(Num, MoveNum) ->
    erlang:erase(),

    Objects = [#object{id = Id, x = util:rand(1, ?MAP_WIDTH), y = util:rand(1, ?MAP_HEIGHT)}|| Id <- lists:seq(1, Num)],
    %% 全部进入
    [enter_object(E) || E <- Objects],

    %% 全部移动
    T1 = util:msunixtime(),
    Objects2 = lists:sublist(get_map_objects(), MoveNum),
    Cnt = lists:foldl(fun(E, Acc) ->
        {Tx, Ty} = rand_target_pos(E#object.x, E#object.y),
        {EnterObjects, MoveObjects, LeaveObjects} = move_object(E, Tx, Ty),
        Acc + length(EnterObjects) + length(MoveObjects) + length(LeaveObjects)
                      end, 0, Objects2),
    T2 = util:msunixtime(),
    ?SUNB("test aoi, Object Num=~w, Broadcast Cnt=~w, Time=~wms", [Num, Cnt, T2-T1]),

    %% 全部离开
    [leave_object(E) || E <- Objects],
    ok.

%% =========================== local function ===========================
get_map_objects() ->
    case erlang:get(?DICT_MAP_OBJECTS) of
        undefined ->
            [];
        Ret ->
            Ret
    end.

set_map_objects(Objects) ->
    erlang:put(?DICT_MAP_OBJECTS, Objects).

add_map_objects(Object) ->
    Objects = get_map_objects(),
    NewObjects = lists:keystore(Object#object.id, #object.id, Objects, Object),
    set_map_objects(NewObjects),
    NewObjects.

remove(Id) ->
    Objects = get_map_objects(),
    case lists:keytake(Id, #object.id, Objects) of
        false ->
            Objects;
        {value, _, RestList} ->
            set_map_objects(RestList),
            RestList
    end.

calc_grid_id(X, Y) ->
    util:ceil(X / ?GRID_WIDTH) * ?CONST_GRID_CALC + util:ceil(Y / ?GRID_HEIGHT).

%% 获取九宫格格子列表
get_nine_grids(GridID) ->
    [GridID-1-?CONST_GRID_CALC, GridID-?CONST_GRID_CALC, GridID+1-?CONST_GRID_CALC,
     GridID-1, GridID, GridID+1,
     GridID-1+?CONST_GRID_CALC, GridID+?CONST_GRID_CALC, GridID+1+?CONST_GRID_CALC].

handle_move_objects(true, _IsMove, _IsLeave, Object, EnterAcc, MoveAcc, LeaveAcc) ->
    {[Object|EnterAcc], MoveAcc, LeaveAcc};
handle_move_objects(_IsEnter, true, _IsLeave, Object, EnterAcc, MoveAcc, LeaveAcc) ->
    {EnterAcc, [Object|MoveAcc], LeaveAcc};
handle_move_objects(_IsEnter, _IsMove, true, Object, EnterAcc, MoveAcc, LeaveAcc) ->
    {EnterAcc, MoveAcc, [Object|LeaveAcc]};
handle_move_objects(_IsEnter, _IsMove, _IsLeave, _Object, EnterAcc, MoveAcc, LeaveAcc) ->
    {EnterAcc, MoveAcc, LeaveAcc}.

rand_target_pos(X, Y) ->
    List = [{-10,+10}, {0,+10}, {+10,+10},
            {-10,0},            {+10,0},
            {-10,-10}, {0,-10}, {+10,-10}],
    {Dx, Dy} = list_util:rand(List),
    {X+Dx, Y+Dy}.