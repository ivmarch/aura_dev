"""
Create or update `resolution_controller` next to this Text DAT.

Use: press Ctrl+R in this Text DAT.
"""


def _set_first_existing_par(op_node, names, value):
    for name in names:
        par = getattr(op_node.par, name, None)
        if par is None:
            continue
        try:
            par.val = value
        except Exception:
            try:
                setattr(op_node.par, name, value)
            except Exception:
                continue
        return True
    return False


def _owner_dat():
    script_dat = globals().get('me')
    if script_dat is not None:
        return script_dat
    return None


def _set_int_par_range(par, min_value, max_value):
    """Set display/edit range for integer custom parameters (no clamp)."""
    min_value = int(min_value)
    max_value = int(max_value)

    try:
        par.min = min_value
    except Exception:
        pass
    try:
        par.max = max_value
    except Exception:
        pass
    # Some TD builds show/edit normalized range fields separately.
    for attr, value in (
        ('normMin', min_value),
        ('normMax', max_value),
        ('minNorm', min_value),
        ('maxNorm', max_value),
        ('minnorm', min_value),
        ('maxnorm', max_value),
    ):
        try:
            setattr(par, attr, value)
        except Exception:
            pass
    try:
        par.clampMin = False
    except Exception:
        pass
    try:
        par.clampMax = False
    except Exception:
        pass


def _ensure_parameters(controller):
    prev_w = 1920
    prev_h = 1080
    if getattr(controller.par, 'Resolutionw', None) is not None:
        try:
            prev_w = int(controller.par.Resolutionw.eval())
        except Exception:
            pass
    if getattr(controller.par, 'Resolutionh', None) is not None:
        try:
            prev_h = int(controller.par.Resolutionh.eval())
        except Exception:
            pass

    # Rebuild custom parameters to remove obsolete controls (Target Path, Apply).
    try:
        controller.destroyCustomPars()
    except Exception:
        pass

    page = controller.appendCustomPage('Resolution Control')

    p = page.appendInt('Resolutionw', label='Width')
    p[0].default = 1920
    p[0].val = prev_w
    _set_int_par_range(controller.par.Resolutionw, 1, 2560)

    p = page.appendInt('Resolutionh', label='Height')
    p[0].default = 1080
    p[0].val = prev_h
    _set_int_par_range(controller.par.Resolutionh, 1, 1280)

    page.appendPulse('Bindselected', label='Bind Selected')
    page.appendPulse('Unbind', label='Unbind')

    return controller


def _ensure_apply_exec(controller):
    """
    Create/update internal Parameter Execute DAT bound to controller parameters.
    """
    exec_dat = controller.op('apply_exec')
    if exec_dat is None:
        exec_dat = controller.create(parameterexecuteDAT, 'apply_exec')

    controller_path = controller.path

    exec_dat.text = '''"""
Auto-generated callbacks for resolution_controller.
Bindselected: bind selected components' glsl1 resolution to controller Width/Height.
Unbind: remove bindings from selected components and keep current values.
"""

def onPulse(par):
    if par.name not in ('Bindselected', 'Unbind'):
        return
    ctrl = parent()
    width = int(ctrl.par.Resolutionw.eval()) if hasattr(ctrl.par, 'Resolutionw') else -1
    height = int(ctrl.par.Resolutionh.eval()) if hasattr(ctrl.par, 'Resolutionh') else -1

    pane = getattr(ui.panes, 'current', None)
    if pane is None or not hasattr(pane, 'owner') or pane.owner is None:
        print('[WARN] No active Network Editor pane')
        return

    selected = []
    for op_node in pane.owner.selectedChildren:
        try:
            if op_node.isCOMP:
                selected.append(op_node)
        except Exception:
            pass

    if not selected:
        print('[WARN] No selected components')
        return

    bound = 0
    scanned = 0
    for comp in selected:
        if comp.path == ctrl.path:
            continue

        scanned += 1
        glsl = comp.op('glsl1')
        if glsl is None:
            print(f'[WARN] {comp.path}: missing glsl1')
            continue
        if glsl.type != 'glsl':
            print(f'[WARN] {comp.path}: glsl1 type is {glsl.type}')
            continue

        if hasattr(glsl.par, 'resolutionw') and hasattr(glsl.par, 'resolutionh'):
            if par.name == 'Bindselected':
                try:
                    glsl.par.resolutionw.mode = ParMode.EXPRESSION
                    glsl.par.resolutionw.expr = f"op('{ctrl.path}').par.Resolutionw"
                    glsl.par.resolutionh.mode = ParMode.EXPRESSION
                    glsl.par.resolutionh.expr = f"op('{ctrl.path}').par.Resolutionh"
                    rw = glsl.par.resolutionw.eval()
                    rh = glsl.par.resolutionh.eval()
                    print(f'[BIND] {comp.path}/glsl1 -> controller ({rw}x{rh})')
                    bound += 1
                except Exception as exc:
                    print(f'[WARN] {comp.path}: bind failed ({exc})')
            else:
                try:
                    rw = glsl.par.resolutionw.eval()
                    rh = glsl.par.resolutionh.eval()
                    glsl.par.resolutionw.mode = ParMode.CONSTANT
                    glsl.par.resolutionh.mode = ParMode.CONSTANT
                    glsl.par.resolutionw.val = int(rw)
                    glsl.par.resolutionh.val = int(rh)
                    glsl.par.resolutionw.expr = ''
                    glsl.par.resolutionh.expr = ''
                    print(f'[UNBIND] {comp.path}/glsl1 -> kept {int(rw)}x{int(rh)}')
                    bound += 1
                except Exception as exc:
                    print(f'[WARN] {comp.path}: unbind failed ({exc})')
        else:
            print(f'[WARN] {comp.path}: missing resolutionw/resolutionh')

    if par.name == 'Bindselected':
        print(f'[DONE] Bound {bound}/{scanned} selected components (controller {width}x{height})')
    else:
        print(f'[DONE] Unbound {bound}/{scanned} selected components')
    return
'''

    _set_first_existing_par(exec_dat, ('active',), True)
    _set_first_existing_par(exec_dat, ('file',), '')
    _set_first_existing_par(exec_dat, ('op', 'ops'), controller_path)
    _set_first_existing_par(exec_dat, ('parameters', 'pars'), '*')
    _set_first_existing_par(exec_dat, ('pulse', 'onpulse'), True)
    _set_first_existing_par(exec_dat, ('valuechange',), False)
    _set_first_existing_par(exec_dat, ('valueschange',), False)
    _set_first_existing_par(exec_dat, ('whileon',), False)
    _set_first_existing_par(exec_dat, ('whileoff',), False)
    return exec_dat


def create_controller():
    script_dat = _owner_dat()
    if script_dat is None:
        print('Error: run this from a Text DAT (Ctrl+R).')
        return None

    target = script_dat.parent()
    if target is None:
        print('Error: cannot resolve parent network for Text DAT.')
        return None

    name = 'resolution_controller'
    controller = target.op(name)
    created = False
    if controller is None:
        controller = target.create(baseCOMP, name)
        created = True

    if created:
        controller.nodeX = script_dat.nodeX + 220
        controller.nodeY = script_dat.nodeY
    _ensure_parameters(controller)
    exec_dat = _ensure_apply_exec(controller)

    print(f'{"Created" if created else "Updated"}: {controller.path}')
    print(f'Configured: {controller.path}/apply_exec (listens to Bindselected + Unbind pulse)')
    if exec_dat is not None:
        print(f'DEBUG: apply_exec OPs="{controller.path}" Parameters="*" Pulse=On')
    return controller


# Ctrl+R entrypoint
create_controller()
