#include "script_component.hpp"
/*
 * Author: nkenny
 * Leader calls for extended suppressive fire towards buildings or location
 *
 * Arguments:
 * 0: Group leader <OBJECT>
 * 1: Group threat unit <OBJECT> or position <ARRAY>
 * 2: Units in group, default all <ARRAY>
 *
 * Return Value:
 * success
 *
 * Example:
 * [bob, angryJoe] call lambs_danger_fnc_leaderSuppress;
 *
 * Public: No
*/
params ["_unit", "_target", ["_units", []]];

// find target
_target = _target call CBA_fnc_getPos;

// stopped or static
if (!(attackEnabled _unit) || {stopped _unit}) exitWith {false};

// find units
if (_units isEqualTo []) then {
    _units = (units _unit) select {_x call FUNC(isAlive) && {!isPlayer _x}};
};

// find vehicles
private _vehicles = [];
{
    if (!(isNull objectParent _x) && {isTouchingGround vehicle _x} && {canFire vehicle _x}) then {
        _vehicles pushBackUnique vehicle _x;
    };
} foreach units _unit;

// sort building locations
private _pos = [_target, 20, true, true] call FUNC(findBuildings);
_pos append ((nearestTerrainObjects [ _target, ["HIDE", "TREE", "BUSH", "SMALL TREE"], 8, false, true ]) apply {getPos _x});
_pos pushBack _target;

// sort cycles
private _cycle = selectRandom [3, 3, 4, 5];

// set tasks
_unit setVariable [QGVAR(currentTarget), _target];
_unit setVariable [QGVAR(currentTask), "Leader Suppress"];

// gesture
[_unit, ["gesturePoint"]] call FUNC(gesture);

// leader callout
[_unit, "combat", "SuppressiveFire", 125] call FUNC(doCallout);

// ready group
(group _unit) setFormDir (_unit getDir _target);

// manoeuvre function
private _fnc_suppress = {
    params ["_cycle", "_units", "_vehicles", "_pos", "_fnc_suppress"];

    // update
    _units = _units select {_x call FUNC(isAlive) && {!isPlayer _x}};
    _vehicles = _vehicles select {canfire _x};
    _cycle = _cycle - 1;

    // infantry
    {

        // ready
        //_x setVariable [QGVAR(forceMOVE), true];
        _x setVariable [QGVAR(currentTask), "Group Suppress"];
        private _posAGL = selectRandom _pos;

        // suppressive fire
        _x forceSpeed 1;
        _x setUnitPosWeak "MIDDLE";
        private _suppress = [_x, AGLtoASL _posAGL, true] call FUNC(suppress);

        // no LOS
        if !(_suppress) then {

            // move forward
            _x forceSpeed 3;
            _x doMove (_x getPos [8 + random 6, _x getdir _posAGL]);
            _x setVariable [QGVAR(currentTask), "Group Suppress (Move)"];

        };

    } foreach _units;

    // vehicles
    {
        private _posAGL = selectRandom _pos;
        _x doWatch AGLtoASL _posAGL;
        [_x, _posAGL] call FUNC(vehicleSuppress);

    } foreach _vehicles;

    // recursive cyclic
    if (_cycle > 0 && {!(_units isEqualTo [])}) then {
        [
            _fnc_suppress,
            [_cycle, _units, _vehicles, _pos, _fnc_suppress],
            3 + random 10
        ] call CBA_fnc_waitAndExecute;
    };
};

// execute recursive cycle
[_cycle, _units, _vehicles, _pos, _fnc_suppress] call _fnc_suppress;

// end
true