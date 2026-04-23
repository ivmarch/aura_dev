"""
Batch control for GLSL TOP parameters on selected components.

Use case:
- Select one or more COMP nodes in Network Editor.
- Each selected COMP should contain a child TOP named "glsl1".
- Run this script to set resolution-related parameters in bulk.
"""


# Default values from your example.
DEFAULT_SETTINGS = {
    'resolution': 9,   # "Specify" mode in most TOPs
    'resolutionw': 2560,
    'resolutionh': 500,
}


def _get_selected_components():
    """Returns selected operators in the currently active Network Editor."""
    pane = ui.panes.current
    if pane and hasattr(pane, 'owner') and pane.owner is not None:
        return [op_node for op_node in pane.owner.selectedChildren if op_node.isCOMP]
    return []


def _set_par_if_exists(target_op, par_name, value):
    """Safely sets parameter if it exists on the operator."""
    par = getattr(target_op.par, par_name, None)
    if par is None:
        return False, 'missing parameter'

    try:
        par.val = value
        return True, ''
    except Exception as exc:
        return False, str(exc)


def apply_to_selected(settings=None, glsl_name='glsl1'):
    """
    Apply settings to child glsl TOP in each selected COMP.

    Example from Textport:
        op('scripts/glsl_batch_control').module.apply_to_selected()

    Example with custom values:
        op('scripts/glsl_batch_control').module.apply_to_selected({
            'resolution': 9,
            'resolutionw': 1920,
            'resolutionh': 1080,
        })
    """
    if settings is None:
        settings = dict(DEFAULT_SETTINGS)

    selected_comps = _get_selected_components()
    if not selected_comps:
        print('No selected COMP nodes in active Network Editor.')
        return

    processed = 0
    updated = 0

    for comp in selected_comps:
        glsl = comp.op(glsl_name)
        if glsl is None:
            print(f'- {comp.path}: skipped (no "{glsl_name}" child)')
            continue

        processed += 1
        for par_name, value in settings.items():
            ok, info = _set_par_if_exists(glsl, par_name, value)
            if ok:
                updated += 1
                print(f'  {comp.path}/{glsl_name}.{par_name} = {value}')
            else:
                print(f'  {comp.path}/{glsl_name}.{par_name}: skipped ({info})')

    print(f'\nDone. Components with "{glsl_name}": {processed}, parameters updated: {updated}.')

