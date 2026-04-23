"""
Shader Wrapper — Parameter Execute DAT callback
Загортає GLSL TOP в Container COMP з custom параметрами.

Використання:
1. На компоненті shader_wrapper вкажи в параметрі Source OP потрібний GLSL TOP
2. Натисни Wrap
3. Поруч з джерелом з'явиться новий Container COMP з параметрами
"""

import re


def uniform_base_name(uname):
    """Акуратно прибирає префікс u у стилі GLSL (uTime, u_color)."""
    if not uname:
        return ''
    if uname.startswith('u') and len(uname) > 1 and (uname[1].isupper() or uname[1] == '_'):
        return uname[1:]
    return uname


def sanitize_name(uname):
    """TD: Uppercase first, then lowercase/digits only; no trailing digit."""
    raw = uniform_base_name(uname)
    # Прибираємо `_` та будь-які неалфанумеричні символи.
    name = ''.join(re.findall(r'[A-Za-z0-9]+', raw))
    if not name:
        name = 'Param'
    else:
        name = name[0].upper() + name[1:].lower()
    if len(name) < 2:
        name = name + 'val'
    if name[-1].isdigit():
        name = name + 'p'
    return name


def set_bind(par, expr):
    """Двосторонній binding між параметрами"""
    try:
        par.mode = ParMode.BIND
        par.bindExpr = expr
    except Exception:
        par.mode = ParMode.EXPRESSION
        par.expr = expr


def onPulse(par):
    if par.name != 'Wrap':
        return

    wrapper_comp = parent()
    source = wrapper_comp.par.Sourceop.eval()

    if source is None:
        print('Помилка: вкажи GLSL TOP в параметрі Source OP')
        return

    if source.type != 'glsl':
        print(f'Помилка: {source.name} це {source.type}, потрібен GLSL TOP')
        return

    target_net = source.parent()

    # читаємо vectors з GLSL TOP
    vectors = []
    for i in range(40):
        try:
            name_par = getattr(source.par, f'vec{i}name')
            uname = name_par.eval()
            if uname == '' or uname == 'iTime':
                continue

            vx = getattr(source.par, f'vec{i}valuex').eval()
            vy = getattr(source.par, f'vec{i}valuey').eval()
            vz = getattr(source.par, f'vec{i}valuez').eval()
            vw = getattr(source.par, f'vec{i}valuew').eval()

            vectors.append({
                'uname': uname,
                'pname': sanitize_name(uname),
                'label': uniform_base_name(uname),
                'idx':   i,
                'vals':  (vx, vy, vz, vw)
            })
        except AttributeError:
            break

    # типи uniform з коду шейдера
    code_dat_name = source.par.pixeldat.eval()
    uniform_types = {}
    if code_dat_name:
        code_dat = op(code_dat_name)
        if code_dat:
            for m in re.finditer(r'uniform\s+(\w+)\s+(\w+)\s*;', code_dat.text):
                uniform_types[m.group(2)] = m.group(1)

    # створюємо Container COMP
    new_comp = target_net.create(containerCOMP, f'{source.name}_wrapped')
    new_comp.nodeX = source.nodeX + 250
    new_comp.nodeY = source.nodeY

    X_STEP = 200

    # Text DAT зі шейдером
    if code_dat_name:
        src_text = op(code_dat_name)
        new_text = new_comp.copy(src_text, name='shader_code')
        new_text.nodeX = 0
        new_text.nodeY = 200

    # GLSL TOP (копія оригіналу)
    new_glsl = new_comp.copy(source, name='glsl1')
    new_glsl.nodeX = X_STEP * 2
    new_glsl.nodeY = 0
    if code_dat_name:
        new_glsl.par.pixeldat = 'shader_code'

    # Null TOP
    new_null = new_comp.create(nullTOP, 'null1')
    new_null.nodeX = X_STEP * 3
    new_null.nodeY = 0
    new_null.inputConnectors[0].connect(new_glsl)

    # Out TOP
    new_out = new_comp.create(outTOP, 'out1')
    new_out.nodeX = X_STEP * 4
    new_out.nodeY = 0
    new_out.inputConnectors[0].connect(new_null)

    # прев'ю
    try:
        new_comp.par.top = './out1'
    except AttributeError:
        pass
    new_comp.par.opviewer = 'out1'
    new_comp.viewer = True

    # custom параметри
    page = new_comp.appendCustomPage('Shader')
    success = 0

    for v in vectors:
        uname = v['uname']
        pname = v['pname']
        label = v['label']
        gtype = uniform_types.get(uname, 'float')
        i = v['idx']
        vx, vy, vz, vw = v['vals']

        print(f'[{i}] {gtype} {uname} -> {pname} (label: {label})')

        try:
            if gtype == 'float':
                p = page.appendFloat(pname, label=label)
                p[0].default = vx
                p[0].val = vx
                set_bind(getattr(new_glsl.par, f'vec{i}valuex'),
                         f'parent().par.{pname}')

            elif gtype == 'int':
                p = page.appendInt(pname, label=label)
                p[0].default = int(vx)
                p[0].val = int(vx)
                set_bind(getattr(new_glsl.par, f'vec{i}valuex'),
                         f'parent().par.{pname}')

            elif gtype == 'vec2':
                p = page.appendXY(pname, label=label)
                p[0].default = vx; p[0].val = vx
                p[1].default = vy; p[1].val = vy
                set_bind(getattr(new_glsl.par, f'vec{i}valuex'),
                         f'parent().par.{pname}x')
                set_bind(getattr(new_glsl.par, f'vec{i}valuey'),
                         f'parent().par.{pname}y')

            elif gtype == 'vec3':
                p = page.appendRGB(pname, label=label)
                p[0].default = vx; p[0].val = vx
                p[1].default = vy; p[1].val = vy
                p[2].default = vz; p[2].val = vz
                set_bind(getattr(new_glsl.par, f'vec{i}valuex'),
                         f'parent().par.{pname}r')
                set_bind(getattr(new_glsl.par, f'vec{i}valuey'),
                         f'parent().par.{pname}g')
                set_bind(getattr(new_glsl.par, f'vec{i}valuez'),
                         f'parent().par.{pname}b')

            elif gtype == 'vec4':
                p = page.appendRGBA(pname, label=label)
                p[0].default = vx; p[0].val = vx
                p[1].default = vy; p[1].val = vy
                p[2].default = vz; p[2].val = vz
                p[3].default = vw; p[3].val = vw
                set_bind(getattr(new_glsl.par, f'vec{i}valuex'),
                         f'parent().par.{pname}r')
                set_bind(getattr(new_glsl.par, f'vec{i}valuey'),
                         f'parent().par.{pname}g')
                set_bind(getattr(new_glsl.par, f'vec{i}valuez'),
                         f'parent().par.{pname}b')
                set_bind(getattr(new_glsl.par, f'vec{i}valuew'),
                         f'parent().par.{pname}a')

            success += 1

        except Exception as e:
            print(f'  помилка для {pname}: {e}')

    print(f'\n{new_comp.name}: {success}/{len(vectors)} параметрів додано')
    return