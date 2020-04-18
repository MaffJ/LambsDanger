#include "script_component.hpp"
/*
 * Author: nkenny
 * Leader calls for extended aggresive manoeuvres towards buildings or location
 *
 * Arguments:
 * 0: Group leader <OBJECT>
 * 1: Group threat unit <OBJECT> or position <ARRAY>
 * 2: Units in group, default all <ARRAY>
 * 3: How many assault cycles, default four <NUMBER>
 *
 * Return Value:
 * success
 *
 * Example:
 * [bob, angryJoe] call lambs_danger_fnc_leaderManoeuvre;
 *
 * Public: No
*/
params ["_unit", "_target", ["_units", []], ["_cycle", 3]];

// stopped or static
if (!(attackEnabled _unit) || {stopped _unit}) exitWith {false};

// find target
_target = _target call CBA_fnc_getPos;

// check CQB ~ exit if in close combat other functions will do the work - nkenny
if (_unit distance2D _target < GVAR(CQB_range)) exitWith {

    [_unit, _target] call FUNC(leaderAssaultClose);

    false
};

// find units
if (_units isEqualTo []) then {
    _units = (units _unit) select {_x call FUNC(isAlive) && {!isPlayer _x}};
};

// sort building locations
private _pos = [_target, 12, true, false] call FUNC(findBuildings);
_pos pushBack _target;

// find overwatch position
private _overwatch = [getPos _unit, ((_unit distance2d _target) / 2) min 200, 100, 8, _target] call FUNC(findOverwatch);

// overwatch Failed ~ pick forest or house locations
if (_overwatch isEqualto []) then {

    _overwatch = selectBestPlaces [_target, ((_unit distance2d _target) / 2) min 200, "(1 + forest + trees + houses) * (1 - meadow) * (1 - deadBody)", 100 , 3] apply {_x select 0};
    _overwatch = _overwatch select {!(surfaceIsWater _x)};
    _overwatch = selectRandom _overwatch;

};

// overwatch failed again -- randomise
if (_overwatch isEqualto []) then {_overWatch = _target getPos [75, random 360]};

// set tasks
_unit setVariable [QGVAR(currentTarget), _target];
_unit setVariable [QGVAR(currentTask), "Leader Flank"];

// gesture
[_unit, ["gestureGo"]] call FUNC(gesture);
[_units select (count _units - 1), ["gestureGoB"]] call FUNC(gesture);

// leader callout
[_unit, "combat", selectRandom ["OnYourFeet ", "Advance"], 125] call FUNC(doCallout);

// ready group
(group _unit) setFormDir (_unit getDir _target);
(group _unit) move _overwatch;

// manoeuvre function
private _fnc_manoeuvre = {
    params ["_cycle", "_units", "_pos", "_overwatch", "_fnc_manoeuvre"];

    // update
    _units = _units select {_x call FUNC(isAlive) && {!isPlayer _x}};
    _cycle = _cycle - 1;

    {
        private _posASL = AGLtoASL (selectRandom _pos);

        // Half suppress -- Half manoeuvre
        if (!(terrainIntersectASL [eyePos _x, _posASL]) && {RND(0.65)}) then {
            
            _x doWatch _posASL;
            [_x, _posASL, true] call FUNC(suppress);

        } else {

            // manoeuvre
            _x forceSpeed 4;
            _x setUnitPosWeak "MIDDLE";
            _x setVariable [QGVAR(currentTask), "Group Flank"];
            _x setVariable [QGVAR(forceMOVE), getSuppression _x > 0.5];

            // force movement
            _x doMove _overwatch;

        };
    } foreach _units;

    // recursive cyclic
    if (_cycle > 0 && {!(_units isEqualTo [])}) then {
        [
            _fnc_manoeuvre,
            [_cycle, _units, _pos, _overwatch, _fnc_manoeuvre],
            10 + random 6
        ] call CBA_fnc_waitAndExecute;
    };
};

// execute recursive cycle
[_cycle, _units, _pos, _overwatch, _fnc_manoeuvre] call _fnc_manoeuvre;

// end
true