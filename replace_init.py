#!/usr/bin/env python3
"""Replace .init( calls with full type names to avoid lizard false positives."""

import re
import os

BASE = '/Users/sarthak/Desktop/fleet/setline/'

# Non-ambiguous mappings: paramName -> full type name
SIMPLE_MAP = {
    'repTarget: .init(': 'repTarget: SetTarget.RepTarget(',
    'timeTarget: .init(': 'timeTarget: SetTarget.TimeTarget(',
    'distanceTarget: .init(': 'distanceTarget: SetTarget.DistanceTarget(',
    'loadMetrics: .init(': 'loadMetrics: SetSegment.LoadMetrics(',
    'enduranceMetrics: .init(': 'enduranceMetrics: SetSegment.EnduranceMetrics(',
    'exerciseRef: .init(': 'exerciseRef: WorkoutStep.ExerciseRef(',
    'context: .init(': 'context: WorkoutSession.SessionContext(',
    'sync: .init(': 'sync: SetlineDocument.SyncInfo(',
    'timing: .init(': 'timing: ExerciseGoal.GoalTiming(',
    'anatomy: .init(': 'anatomy: ExerciseDefinition.Anatomy(',
}

# Ambiguous mappings need context from enclosing constructor
# config: .init( -> depends on whether we're inside PlannedSet, WorkoutStep, or ExerciseDefinition
# state: .init( -> depends on whether we're inside WorkoutStep or WorkoutSession
# load: .init( -> depends on whether we're inside ProgressionRecommendation

def replace_in_file(filepath):
    with open(filepath, 'r') as f:
        content = f.read()

    # Simple replacements
    for old, new in SIMPLE_MAP.items():
        content = content.replace(old, new)

    # Ambiguous: config, state, load
    # We need to find the enclosing constructor call
    # Strategy: find patterns like "ConstructorName(\n ... paramName: .init("
    # and replace based on the constructor

    lines = content.split('\n')
    result_lines = []
    enclosing_ctor = None  # Stack of enclosing constructors
    ctor_stack = []

    i = 0
    while i < len(lines):
        line = lines[i]

        # Track enclosing constructor by looking for patterns like "ConstructorName("
        # We need to track paren depth
        # Simple approach: look for known constructor names followed by (
        for ctor in ['PlannedSet(', 'WorkoutStep(', 'ExerciseDefinition(',
                     'WorkoutSession(', 'ProgressionRecommendation(', 'SetTarget(']:
            if ctor in line:
                ctor_stack.append(ctor.rstrip('('))

        # Check for ambiguous .init() calls
        if 'config: .init(' in line:
            # Determine which constructor we're inside
            if 'PlannedSet' in ctor_stack:
                line = line.replace('config: .init(', 'config: PlannedSet.SetConfig(')
            elif 'WorkoutStep' in ctor_stack:
                line = line.replace('config: .init(', 'config: WorkoutStep.StepConfig(')
            elif 'ExerciseDefinition' in ctor_stack:
                line = line.replace('config: .init(', 'config: ExerciseDefinition.ExerciseConfig(')

        if 'state: .init(' in line:
            if 'WorkoutStep' in ctor_stack:
                line = line.replace('state: .init(', 'state: WorkoutStep.StepState(')
            elif 'WorkoutSession' in ctor_stack:
                line = line.replace('state: .init(', 'state: WorkoutSession.SessionState(')

        if 'load: .init(' in line:
            if 'ProgressionRecommendation' in ctor_stack:
                line = line.replace('load: .init(', 'load: ProgressionRecommendation.LoadInfo(')

        # Pop constructor stack when we see closing parens
        # Count parens in the line
        opens = line.count('(')
        closes = line.count(')')
        if closes > opens:
            # We're closing more than opening - pop constructors
            net_close = closes - opens
            for _ in range(net_close):
                if ctor_stack:
                    ctor_stack.pop()

        result_lines.append(line)
        i += 1

    content = '\n'.join(result_lines)

    with open(filepath, 'w') as f:
        f.write(content)

# Process all Swift files in ios/Sources
for root, dirs, files in os.walk(BASE + 'ios/Sources'):
    for f in files:
        if f.endswith('.swift'):
            replace_in_file(os.path.join(root, f))

# Process test files
for root, dirs, files in os.walk(BASE + 'ios/Tests'):
    for f in files:
        if f.endswith('.swift'):
            replace_in_file(os.path.join(root, f))

print("Done replacing .init() calls with full type names")
