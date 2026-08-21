#!/usr/bin/env python3
"""Transform Swift constructor call sites to use config struct grouping."""

import re
import sys
from collections import OrderedDict


def find_calls(text, constructor_name):
    """Find all calls to constructor_name( in text, using paren matching.
    Returns list of (start, end, call_text) tuples."""
    calls = []
    pattern = constructor_name + '('
    idx = 0
    while True:
        pos = text.find(pattern, idx)
        if pos == -1:
            break
        # Make sure it's not part of a longer identifier
        if pos > 0 and (text[pos-1].isalnum() or text[pos-1] == '_'):
            idx = pos + 1
            continue
        # Find matching closing paren
        depth = 1
        i = pos + len(pattern)
        in_string = False
        while i < len(text) and depth > 0:
            c = text[i]
            if in_string:
                if c == '\\':
                    i += 2
                    continue
                if c == '"':
                    in_string = False
            elif c == '"':
                in_string = True
            elif c == '(':
                depth += 1
            elif c == ')':
                depth -= 1
            i += 1
        calls.append((pos, i, text[pos:i]))
        idx = i
    return calls


def parse_params(call_text):
    """Parse named params from a call like ConstructorName(param1: val1, param2: val2).
    Returns list of (param_name, value_text) tuples. param_name may be None for positional args."""
    # Remove constructor name and outer parens
    paren_start = call_text.index('(')
    inner = call_text[paren_start+1:-1]

    # Split by commas at depth 0, respecting strings
    params = []
    current = ''
    depth = 0
    in_string = False
    i = 0
    while i < len(inner):
        c = inner[i]
        if in_string:
            if c == '\\':
                current += c
                if i + 1 < len(inner):
                    current += inner[i+1]
                i += 2
                continue
            current += c
            if c == '"':
                in_string = False
            i += 1
            continue
        if c == '"':
            in_string = True
            current += c
        elif c in '([{':
            depth += 1
            current += c
        elif c in ')]}':
            depth -= 1
            current += c
        elif c == ',' and depth == 0:
            params.append(current.strip())
            current = ''
        else:
            current += c
        i += 1
    if current.strip():
        params.append(current.strip())

    # Parse each param as "name: value"
    result = []
    for p in params:
        # Find first colon at depth 0 (not inside parens or strings)
        colon_pos = -1
        d = 0
        in_s = False
        for j, c in enumerate(p):
            if in_s:
                if c == '\\':
                    continue
                if c == '"':
                    in_s = False
                continue
            if c == '"':
                in_s = True
            elif c in '([{':
                d += 1
            elif c in ')]}':
                d -= 1
            elif c == ':' and d == 0:
                colon_pos = j
                break
        if colon_pos >= 0:
            name = p[:colon_pos].strip()
            value = p[colon_pos+1:].strip()
            result.append((name, value))
        else:
            result.append((None, p))

    return result


def reconstruct_call(constructor_name, groups, core_params, param_order, indent='        '):
    """Reconstruct a call with grouped params.

    groups: OrderedDict of group_name -> list of (param_name, value)
    core_params: list of (param_name, value) for non-grouped params
    param_order: list describing the new init param order, each element is
                 ('core', param_name) or ('group', group_name)
    """
    # Build the args in order
    args = []
    for kind, name in param_order:
        if kind == 'group':
            group_params = groups.get(name, [])
            if group_params:
                inner = ', '.join(f'{n}: {v}' for n, v in group_params)
                args.append(f'{name}: .init({inner})')
        elif kind == 'core':
            for pn, pv in core_params:
                if pn == name:
                    args.append(f'{pn}: {pv}')
                    break

    if len(args) == 0:
        return f'{constructor_name}()'
    elif len(args) == 1:
        return f'{constructor_name}({args[0]})'
    else:
        # Multi-line format
        lines = [f'{constructor_name}(']
        for i, arg in enumerate(args):
            comma = ',' if i < len(args) - 1 else ''
            lines.append(f'{indent}{arg}{comma}')
        lines.append(f'{indent[:-4]})')  # Close with less indent
        return '\n'.join(lines)


def transform_file(filepath, transforms):
    """Transform a file applying multiple constructor transforms.

    transforms: dict of constructor_name -> {
        'groups': OrderedDict of group_name -> list of param names,
        'core': list of core param names,
        'order': list of ('core', name) or ('group', group_name)
    }
    """
    with open(filepath, 'r') as f:
        text = f.read()

    count = 0
    while True:
        # Find all calls in the current text
        all_calls = []
        for ctor_name, config in transforms.items():
            calls = find_calls(text, ctor_name)
            for start, end, call_text in calls:
                all_calls.append((start, end, call_text, ctor_name, config))

        # Find the innermost call that needs transformation
        best = None
        for start, end, call_text, ctor_name, config in all_calls:
            params = parse_params(call_text)
            if not params:
                continue

            param_names = [p[0] for p in params]
            new_group_names = set()
            for kind, name in config['order']:
                if kind == 'group':
                    new_group_names.add(name)
            old_group_param_names = set()
            for group_name, group_params in config['groups'].items():
                for p in group_params:
                    old_group_param_names.add(p)

            if any(pn in new_group_names for pn in param_names if pn):
                continue
            if not any(pn in old_group_param_names for pn in param_names if pn):
                continue

            if best is None or start > best[0]:
                best = (start, end, call_text, ctor_name, config, params)

        if best is None:
            break

        start, end, call_text, ctor_name, config, params = best

        # Group params
        groups = {}
        core_params = []
        for pn, pv in params:
            placed = False
            for group_name, group_param_names in config['groups'].items():
                if pn in group_param_names:
                    if group_name not in groups:
                        groups[group_name] = []
                    groups[group_name].append((pn, pv))
                    placed = True
                    break
            if not placed:
                core_params.append((pn, pv))

        # Determine indentation
        line_start = text.rfind('\n', 0, start) + 1
        call_indent = ''
        for c in text[line_start:start]:
            if c in ' \t':
                call_indent += c
            else:
                break

        new_text = reconstruct_call(ctor_name, groups, core_params, config['order'], indent=call_indent + '    ')
        text = text[:start] + new_text + text[end:]
        count += 1

    with open(filepath, 'w') as f:
        f.write(text)

    print(f'Transformed {filepath}: {count} call sites')


# Define transforms for each constructor
from collections import OrderedDict as OD

SETTARGET_TRANSFORM = {
    'groups': OD([
        ('repTarget', ['repsLow', 'repsHigh', 'repsInReserve', 'rpe']),
        ('timeTarget', ['tempo', 'timeSeconds', 'holdSeconds']),
        ('distanceTarget', ['distanceMetres', 'paceSecondsPerKilometre', 'heartRateZone']),
    ]),
    'core': ['load', 'perSide', 'legacyDisplay'],
    'order': [
        ('group', 'repTarget'),
        ('group', 'timeTarget'),
        ('group', 'distanceTarget'),
        ('core', 'load'),
        ('core', 'perSide'),
        ('core', 'legacyDisplay'),
    ],
}

EXERCISE_DEFINITION_TRANSFORM = {
    'groups': OD([
        ('anatomy', ['primaryMuscles', 'secondaryMuscles', 'equipment', 'isUnilateral']),
        ('config', ['aliases', 'defaultRest', 'cue', 'goalMetrics']),
    ]),
    'core': ['slug', 'name', 'pillars', 'kind'],
    'order': [
        ('core', 'slug'),
        ('core', 'name'),
        ('core', 'pillars'),
        ('core', 'kind'),
        ('group', 'anatomy'),
        ('group', 'config'),
    ],
}

SETSEGMENT_TRANSFORM = {
    'groups': OD([
        ('loadMetrics', ['weight', 'repetitions', 'rpe', 'repsInReserve', 'reachedFailure', 'assistanceKilograms']),
        ('enduranceMetrics', ['durationSeconds', 'distanceKilometres', 'rangeOfMotionValue', 'averageHeartRate', 'workSeconds']),
    ]),
    'core': ['id', 'side', 'hadPain', 'note'],
    'order': [
        ('core', 'id'),
        ('group', 'loadMetrics'),
        ('group', 'enduranceMetrics'),
        ('core', 'side'),
        ('core', 'hadPain'),
        ('core', 'note'),
    ],
}

PLANNED_SET_TRANSFORM = {
    'groups': OD([
        ('config', ['stepType', 'isOptional']),
    ]),
    'core': ['id', 'label', 'kind', 'target', 'rest', 'cue'],
    'order': [
        ('core', 'id'),
        ('core', 'label'),
        ('core', 'kind'),
        ('core', 'target'),
        ('core', 'rest'),
        ('group', 'config'),
        ('core', 'cue'),
    ],
}

WORKOUT_STEP_TRANSFORM = {
    'groups': OD([
        ('exerciseRef', ['plannedSetID', 'exerciseName', 'exerciseSlug', 'cue', 'label', 'kind']),
        ('config', ['stepType', 'target', 'pillars', 'authoredPosition', 'rest', 'isOptional']),
        ('state', ['status', 'segments', 'isExtra', 'performedPosition', 'completedAt', 'workSeconds']),
    ]),
    'core': ['id'],
    'order': [
        ('core', 'id'),
        ('group', 'exerciseRef'),
        ('group', 'config'),
        ('group', 'state'),
    ],
}

WORKOUT_SESSION_TRANSFORM = {
    'groups': OD([
        ('context', ['templateID', 'templateName', 'startedAt', 'completedAt']),
        ('state', ['steps', 'activeIndex', 'rest', 'programmeWeek', 'programmeDayIndex']),
    ]),
    'core': ['id'],
    'order': [
        ('core', 'id'),
        ('group', 'context'),
        ('group', 'state'),
    ],
}

SETLINE_DOCUMENT_TRANSFORM = {
    'groups': OD([
        ('sync', ['syncState', 'lastSyncedAt']),
    ]),
    'core': ['schemaVersion', 'templates', 'programme', 'activeSession', 'history', 'goals'],
    'order': [
        ('core', 'schemaVersion'),
        ('core', 'templates'),
        ('core', 'programme'),
        ('core', 'activeSession'),
        ('core', 'history'),
        ('core', 'goals'),
        ('group', 'sync'),
    ],
}

EXERCISE_GOAL_TRANSFORM = {
    'groups': OD([
        ('timing', ['targetDate', 'createdAt']),
    ]),
    'core': ['id', 'exerciseName', 'metric', 'targetValue', 'referenceRepetitions', 'note'],
    'order': [
        ('core', 'id'),
        ('core', 'exerciseName'),
        ('core', 'metric'),
        ('core', 'targetValue'),
        ('core', 'referenceRepetitions'),
        ('group', 'timing'),
        ('core', 'note'),
    ],
}

PROGRESSION_RECOMMENDATION_TRANSFORM = {
    'groups': OD([
        ('load', ['currentLoad', 'recommendedLoad']),
    ]),
    'core': ['exerciseName', 'exerciseSlug', 'action', 'lastSessionRepetitions', 'lastSessionDate', 'rationale'],
    'order': [
        ('core', 'exerciseName'),
        ('core', 'exerciseSlug'),
        ('core', 'action'),
        ('group', 'load'),
        ('core', 'lastSessionRepetitions'),
        ('core', 'lastSessionDate'),
        ('core', 'rationale'),
    ],
}


# Apply transforms to each file
files_transforms = {
    'ios/Sources/SetlineCore/TwelveWeekProgramme.swift': {
        'SetTarget': SETTARGET_TRANSFORM,
        'PlannedSet': PLANNED_SET_TRANSFORM,
    },
    'ios/Sources/SetlineCore/ExerciseCatalogue.swift': {
        'ExerciseDefinition': EXERCISE_DEFINITION_TRANSFORM,
    },
    'ios/Sources/SetlineCore/Domain.swift': {
        'SetSegment': SETSEGMENT_TRANSFORM,
        'SetTarget': SETTARGET_TRANSFORM,
        'PlannedSet': PLANNED_SET_TRANSFORM,
        'WorkoutStep': WORKOUT_STEP_TRANSFORM,
        'WorkoutSession': WORKOUT_SESSION_TRANSFORM,
        'SetlineDocument': SETLINE_DOCUMENT_TRANSFORM,
        'ExerciseGoal': EXERCISE_GOAL_TRANSFORM,
    },
    'ios/Sources/SetlineCore/Progression.swift': {
        'ProgressionRecommendation': PROGRESSION_RECOMMENDATION_TRANSFORM,
    },
    'ios/Sources/SetlineCore/Goals.swift': {
        'ExerciseGoal': EXERCISE_GOAL_TRANSFORM,
    },
    'ios/Sources/SetlineCore/SetEntryParser.swift': {
        'SetSegment': SETSEGMENT_TRANSFORM,
    },
    'ios/Sources/Setline/AppModel.swift': {
        'SetSegment': SETSEGMENT_TRANSFORM,
    },
    'ios/Sources/Setline/WorkoutPlayerView.swift': {
        'SetSegment': SETSEGMENT_TRANSFORM,
    },
    'ios/Sources/Setline/PlanViews.swift': {
        'SetTarget': SETTARGET_TRANSFORM,
        'PlannedSet': PLANNED_SET_TRANSFORM,
    },
    'ios/Sources/Setline/ExercisesView.swift': {
        'ExerciseGoal': EXERCISE_GOAL_TRANSFORM,
    },
    'ios/Sources/Setline/SetlinePlatformRecord.swift': {
        'WorkoutSession': WORKOUT_SESSION_TRANSFORM,
    },
    'ios/Tests/SetlineCoreTests/SetlineCoreTests.swift': {
        'SetSegment': SETSEGMENT_TRANSFORM,
        'SetTarget': SETTARGET_TRANSFORM,
        'WorkoutStep': WORKOUT_STEP_TRANSFORM,
        'WorkoutSession': WORKOUT_SESSION_TRANSFORM,
        'ExerciseGoal': EXERCISE_GOAL_TRANSFORM,
    },
    'ios/Tests/SetlineCoreTests/SyncEngineTests.swift': {
        'ExerciseGoal': EXERCISE_GOAL_TRANSFORM,
    },
    'ios/Tests/SetlineCoreTests/SyncCoordinatorTests.swift': {
        'ExerciseGoal': EXERCISE_GOAL_TRANSFORM,
        'WorkoutSession': WORKOUT_SESSION_TRANSFORM,
    },
    'ios/Tests/SetlineTests/SetlinePlatformRecordTests.swift': {
        'WorkoutSession': WORKOUT_SESSION_TRANSFORM,
    },
}

base_dir = '/Users/sarthak/Desktop/fleet/setline/'
for relpath, transforms in files_transforms.items():
    filepath = base_dir + relpath
    try:
        transform_file(filepath, transforms)
    except Exception as e:
        print(f'ERROR transforming {filepath}: {e}')
        import traceback
        traceback.print_exc()
